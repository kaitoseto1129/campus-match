// verify-purchase
//
// クライアント(StoreManager.swift)から、StoreKitで完了した購入のJWS(signedTransactionInfo)を
// 受け取り、Appleの公開ルート証明書(Apple Root CA - G3)までの証明書チェーンと署名を検証したうえで、
// 検証が取れた場合だけサーバー側で「いいね」または「有料会員」を付与する。
//
// これにより、クライアントやAPIを直接叩くだけでは特典を得られなくなる
// (grant_purchased_likes/grant_purchased_membershipはservice_roleからしか呼べない)。
//
// 注意: ローカルのXcodeシミュレーターでのStoreKitテスト(Products.storekit)は、
// Appleの本物のPKIではなくXcodeのテスト用署名を使うため、この検証には失敗する。
// 実際に検証まで含めて動作確認するには、TestFlightまたは実機のSandboxテスターアカウントで
// テストする必要がある(購入UIの動作確認自体はシミュレーターで問題なくできる)。

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { X509Certificate } from "npm:@peculiar/x509@1.12.1";
import { importX509, jwtVerify, decodeProtectedHeader } from "npm:jose@5.9.6";

// https://www.apple.com/certificateauthority/AppleRootCA-G3.cer から取得した、
// Appleが公開している正規のルート証明書(有効期限: 2039年)。
const APPLE_ROOT_CA_G3_PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----`;

// StoreKitのTransaction.jwsRepresentationを渡す前提のbundle idと商品ID。
const BUNDLE_ID = "com.cammatch.app";
const LIKE_PRODUCT_AMOUNTS: Record<string, number> = {
  "com.cammatch.app.likes10": 10,
  "com.cammatch.app.likes50": 50,
  "com.cammatch.app.likes100": 100,
};
const MEMBERSHIP_PRODUCT_ID = "com.cammatch.app.membership.monthly";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function derBase64ToPem(der: string): string {
  const lines = der.match(/.{1,64}/g) ?? [der];
  return `-----BEGIN CERTIFICATE-----\n${lines.join("\n")}\n-----END CERTIFICATE-----`;
}

/// x5cヘッダ(leaf → 中間 → …)を辿り、末尾がAppleの正規ルート証明書と一致し、
/// かつ各証明書が「次の証明書の秘密鍵で署名されている」ことを確認する。
async function verifyCertificateChain(x5c: string[]): Promise<void> {
  if (x5c.length === 0) throw new Error("empty certificate chain");

  const chain = x5c.map((der) => new X509Certificate(derBase64ToPem(der)));
  const root = new X509Certificate(APPLE_ROOT_CA_G3_PEM);

  const now = new Date();
  for (const cert of chain) {
    if (now < cert.notBefore || now > cert.notAfter) {
      throw new Error("certificate expired or not yet valid");
    }
  }

  // leaf -> 中間証明書、の順に「次の証明書が発行者であること」を検証する。
  for (let i = 0; i < chain.length - 1; i++) {
    const isValid = await chain[i].verify({ publicKey: chain[i + 1].publicKey });
    if (!isValid) throw new Error(`certificate chain signature invalid at index ${i}`);
  }

  // チェーンの最後の証明書が、埋め込み済みのApple公式ルート証明書と完全一致するかを確認する
  // (バイト単位の比較なので、偽の「Apple」を名乗る証明書を挟まれても検出できる)。
  const last = chain[chain.length - 1];
  const lastRaw = new Uint8Array(last.rawData);
  const rootRaw = new Uint8Array(root.rawData);
  const matchesRoot =
    lastRaw.length === rootRaw.length && lastRaw.every((b, idx) => b === rootRaw[idx]);
  if (!matchesRoot) {
    // 中間証明書までしか含まれていない場合は、その中間証明書自体がルートで署名されているかを確認する。
    const verifiedByRoot = await last.verify({ publicKey: root.publicKey });
    if (!verifiedByRoot) {
      throw new Error("certificate chain does not terminate at Apple Root CA - G3");
    }
  }
}

async function verifyAppleTransaction(jws: string): Promise<Record<string, unknown>> {
  const header = decodeProtectedHeader(jws) as { x5c?: string[] };
  if (!header.x5c || header.x5c.length === 0) {
    throw new Error("missing x5c in JWS header");
  }

  await verifyCertificateChain(header.x5c);

  const leafPem = derBase64ToPem(header.x5c[0]);
  const publicKey = await importX509(leafPem, "ES256");
  const { payload } = await jwtVerify(jws, publicKey);
  return payload as Record<string, unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
    const userId = userData.user.id;

    const body = await req.json().catch(() => null);
    const transactionJWS = body?.transactionJWS;
    if (!transactionJWS || typeof transactionJWS !== "string") {
      return json({ error: "missing transactionJWS" }, 400);
    }

    const payload = await verifyAppleTransaction(transactionJWS);

    if (payload.bundleId !== BUNDLE_ID) {
      return json({ error: "bundle id mismatch" }, 400);
    }

    const productId = payload.productId as string;
    const transactionId = payload.transactionId as string;
    // サブスクリプションの契約を通して不変のID。解約・失効の通知(apple-notifications)は
    // このIDしか持たないため、ここで保存しておかないと後から利用者を特定できなくなる。
    const originalTransactionId = (payload.originalTransactionId as string) ?? transactionId;
    if (!productId || !transactionId) {
      return json({ error: "malformed transaction payload" }, 400);
    }

    const serviceClient = createClient(supabaseUrl, serviceKey);

    // リプレイ防止: 同じtransactionIdを二度使えないようにする(unique制約でガード)。
    const { error: redeemError } = await serviceClient
      .from("redeemed_transactions")
      .insert({
        transaction_id: transactionId,
        user_id: userId,
        product_id: productId,
        original_transaction_id: originalTransactionId,
      });
    if (redeemError) {
      return json({ error: "transaction already redeemed" }, 409);
    }

    // grant_*が失敗した場合にredeemed_transactionsの記録だけ残ってしまうと、
    // Appleには課金済みなのにunique制約で二度とこのtransactionIdを再送できず、
    // 付与を受け取れないまま詰んでしまう。grant失敗時はここで記録を取り消し、
    // クライアントが同じtransactionを安全に再送(リトライ)できるようにする。
    const rollbackRedemption = async () => {
      await serviceClient
        .from("redeemed_transactions")
        .delete()
        .eq("transaction_id", transactionId);
    };

    if (productId in LIKE_PRODUCT_AMOUNTS) {
      const amount = LIKE_PRODUCT_AMOUNTS[productId];
      const { error } = await serviceClient.rpc("grant_purchased_likes", {
        p_user_id: userId,
        p_amount: amount,
      });
      if (error) {
        console.error("grant_purchased_likes error", error);
        await rollbackRedemption();
        return json({ error: "grant failed" }, 500);
      }
      return json({ success: true, granted: "likes", amount });
    }

    if (productId === MEMBERSHIP_PRODUCT_ID) {
      const { error } = await serviceClient.rpc("grant_purchased_membership", {
        p_user_id: userId,
        p_tier: "vip",
      });
      if (error) {
        console.error("grant_purchased_membership error", error);
        await rollbackRedemption();
        return json({ error: "grant failed" }, 500);
      }
      return json({ success: true, granted: "membership" });
    }

    await rollbackRedemption();
    return json({ error: "unknown product" }, 400);
  } catch (error) {
    console.error("verify-purchase error", error);
    return json({ error: "verification failed" }, 400);
  }
});
