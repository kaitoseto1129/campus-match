// apple-notifications
//
// App Store Server Notifications V2 の受信口。
// サブスクリプション(有料会員)の更新・解約・失効・返金をAppleがここへ通知してくるので、
// それを会員ステータス(profiles.membership_tier)へ反映する。
//
// これが無いと、ユーザーが解約しても membership_tier が 'vip' のまま残り、
// 課金していないのに有料会員特典を使い続けられてしまう
// (クライアント側のsyncMembershipEntitlement()は、会員ステータス画面を開いた時しか走らない)。
//
// App Store Connect > App情報 > App Store Server Notifications に、
// このFunctionのURLを Production / Sandbox それぞれのURLとして登録すること。
// AppleはこのエンドポイントをJWTなしで叩くため、supabase/config.toml で verify_jwt = false にし、
// 代わりに「AppleのルートCAまで署名チェーンが辿れること」で正当性を検証する。

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

const BUNDLE_ID = "com.cammatch.app";
const MEMBERSHIP_PRODUCT_ID = "com.cammatch.app.membership.monthly";

/// 有料会員を維持する通知。更新成功・再加入・返金の取り消しなど。
const GRANT_NOTIFICATIONS = new Set([
  "SUBSCRIBED",
  "DID_RENEW",
  "OFFER_REDEEMED",
  "REFUND_REVERSED",
]);

/// 有料会員を打ち切る通知。解約後の期限到来・課金失敗による失効・返金・families解除など。
const REVOKE_NOTIFICATIONS = new Set([
  "EXPIRED",
  "GRACE_PERIOD_EXPIRED",
  "REFUND",
  "REVOKE",
]);

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

/// x5cヘッダ(leaf → 中間 → …)を辿り、末尾がAppleの正規ルート証明書に到達することを確認する。
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

  for (let i = 0; i < chain.length - 1; i++) {
    const isValid = await chain[i].verify({ publicKey: chain[i + 1].publicKey });
    if (!isValid) throw new Error(`certificate chain signature invalid at index ${i}`);
  }

  const last = chain[chain.length - 1];
  const lastRaw = new Uint8Array(last.rawData);
  const rootRaw = new Uint8Array(root.rawData);
  const matchesRoot =
    lastRaw.length === rootRaw.length && lastRaw.every((b, idx) => b === rootRaw[idx]);
  if (!matchesRoot) {
    const verifiedByRoot = await last.verify({ publicKey: root.publicKey });
    if (!verifiedByRoot) {
      throw new Error("certificate chain does not terminate at Apple Root CA - G3");
    }
  }
}

async function verifySignedPayload(jws: string): Promise<Record<string, unknown>> {
  const header = decodeProtectedHeader(jws) as { x5c?: string[] };
  if (!header.x5c || header.x5c.length === 0) {
    throw new Error("missing x5c in JWS header");
  }
  await verifyCertificateChain(header.x5c);
  const publicKey = await importX509(derBase64ToPem(header.x5c[0]), "ES256");
  const { payload } = await jwtVerify(jws, publicKey);
  return payload as Record<string, unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  try {
    const body = await req.json().catch(() => null);
    const signedPayload = body?.signedPayload;
    if (!signedPayload || typeof signedPayload !== "string") {
      return json({ error: "missing signedPayload" }, 400);
    }

    // 外側のJWS(通知そのもの)を検証する。
    const notification = await verifySignedPayload(signedPayload);
    const notificationType = notification.notificationType as string;
    const subtype = notification.subtype as string | undefined;
    const data = notification.data as Record<string, unknown> | undefined;

    if (!data?.signedTransactionInfo || typeof data.signedTransactionInfo !== "string") {
      // TESTなど取引情報を含まない通知は、検証だけ通して200を返す
      // (Appleは200以外を返すとリトライし続けるため)。
      console.log("notification without transaction info", notificationType, subtype);
      return json({ success: true, ignored: notificationType });
    }

    // 内側のJWS(取引情報)も同じ手順で検証する。
    const transaction = await verifySignedPayload(data.signedTransactionInfo);

    if (transaction.bundleId !== BUNDLE_ID) {
      return json({ error: "bundle id mismatch" }, 400);
    }
    if (transaction.productId !== MEMBERSHIP_PRODUCT_ID) {
      // いいね(消耗型)は購入時に付与済みで、更新・失効の概念がないため何もしない。
      return json({ success: true, ignored: transaction.productId });
    }

    const originalTransactionId = transaction.originalTransactionId as string | undefined;
    if (!originalTransactionId) {
      return json({ error: "missing originalTransactionId" }, 400);
    }

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: userId, error: lookupError } = await serviceClient.rpc(
      "user_id_for_original_transaction",
      { p_original_transaction_id: originalTransactionId },
    );
    if (lookupError) {
      console.error("user lookup error", lookupError);
      return json({ error: "lookup failed" }, 500);
    }
    if (!userId) {
      // 購入検証を経ていない契約(=このアプリのユーザーと紐づかない)。
      // リトライされ続けても解決しないため200で受理だけしておく。
      console.log("no user for originalTransactionId", originalTransactionId);
      return json({ success: true, ignored: "unknown subscription" });
    }

    if (REVOKE_NOTIFICATIONS.has(notificationType)) {
      const { error } = await serviceClient.rpc("revoke_purchased_membership", {
        p_user_id: userId,
      });
      if (error) {
        console.error("revoke_purchased_membership error", error);
        return json({ error: "revoke failed" }, 500);
      }
      console.log("membership revoked", userId, notificationType, subtype);
      return json({ success: true, action: "revoked" });
    }

    if (GRANT_NOTIFICATIONS.has(notificationType)) {
      const { error } = await serviceClient.rpc("grant_purchased_membership", {
        p_user_id: userId,
        p_tier: "vip",
      });
      if (error) {
        console.error("grant_purchased_membership error", error);
        return json({ error: "grant failed" }, 500);
      }
      console.log("membership granted", userId, notificationType, subtype);
      return json({ success: true, action: "granted" });
    }

    // DID_CHANGE_RENEWAL_STATUS(自動更新のオフ)などは、期間満了までは有料会員のままで正しい。
    // 実際に打ち切るのは、後から届くEXPIRED通知を受け取った時。
    console.log("notification acknowledged", notificationType, subtype);
    return json({ success: true, action: "acknowledged" });
  } catch (error) {
    console.error("apple-notifications error", error);
    // 署名検証に失敗したものはAppleからの通知ではないため、400で拒否する。
    return json({ error: "verification failed" }, 400);
  }
});
