// send-push
//
// いいね・マッチ・メッセージ受信時に、対象ユーザーの端末へAPNs経由でプッシュ通知を送る。
//
// クライアント側から「このユーザーにこの内容を通知して」と呼び出される。実際の送信は
// Apple Push Notification service (APNs) のHTTP/2 APIへ、APNs Auth Key(.p8)で署名した
// JWTを添えて直接リクエストする(サードパーティの通知サービスは使わない)。
//
// 動かすには Supabase の Edge Functions > Secrets に以下を設定すること。
//   APNS_AUTH_KEY … developer.apple.comで発行した.p8ファイルの中身(PEM形式そのまま)
//   APNS_KEY_ID   … その鍵のKey ID
//   APNS_TEAM_ID  … Apple DeveloperアカウントのTeam ID
// 未設定の間はログにだけ残して正常終了する(通知が飛ばないだけで、呼び出し元の処理は失敗させない)。

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

// TestFlight/App Store配布のビルドは本番のAPNsエンドポイントに接続するため、
// こちらを既定にしている(Xcodeからの直接デバッグ実行のみSandboxが必要)。
const APNS_HOST = "https://api.push.apple.com";
const BUNDLE_ID = "com.cammatch.app";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// APNs用JWTは最大1時間有効。毎回署名し直さずに使い回すため、関数インスタンス内でキャッシュする。
let cachedJWT: { token: string; issuedAt: number } | null = null;

async function getApnsJWT(): Promise<string | null> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const authKey = Deno.env.get("APNS_AUTH_KEY");
  if (!keyId || !teamId || !authKey) return null;

  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.issuedAt < 1800) {
    return cachedJWT.token;
  }
  const privateKey = await importPKCS8(authKey, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuedAt(now)
    .setIssuer(teamId)
    .sign(privateKey);
  cachedJWT = { token, issuedAt: now };
  return token;
}

async function sendToToken(
  token: string,
  title: string,
  body: string,
  data: Record<string, unknown> | undefined,
  jwt: string,
): Promise<Response> {
  const payload = {
    aps: { alert: { title, body }, sound: "default" },
    ...(data ?? {}),
  };
  return await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }
  try {
    const { userId, title, body, data } = await req.json();
    if (!userId || !title || !body) {
      return json({ success: false, error: "userId, title, body are required" }, 400);
    }

    const jwt = await getApnsJWT();
    if (!jwt) {
      console.log("send-push: APNs secrets not configured, skipping");
      return json({ success: true, sent: 0, skipped: true });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: tokens, error } = await supabase
      .from("push_tokens")
      .select("id, token")
      .eq("user_id", userId);
    if (error) throw error;
    if (!tokens || tokens.length === 0) {
      return json({ success: true, sent: 0 });
    }

    let sent = 0;
    for (const row of tokens) {
      try {
        const res = await sendToToken(row.token, title, body, data, jwt);
        if (res.ok) {
          sent++;
        } else if (res.status === 400 || res.status === 410) {
          // BadDeviceToken / Unregistered … 機種変更・アンインストールなどで無効になったトークンは掃除する。
          await supabase.from("push_tokens").delete().eq("id", row.id);
        } else {
          console.error("apns send failed", res.status, await res.text());
        }
      } catch (sendError) {
        console.error("apns request error", sendError);
      }
    }
    return json({ success: true, sent });
  } catch (error) {
    console.error("send-push error", error);
    return json({ success: false, error: String(error) }, 500);
  }
});
