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

/// 「集まり」機能での関係(応募した/された、または同じ集まりの主催者・承認済みメンバー同士)を確認する。
/// likes/matchesの関係が無い場合の追加チェックとしてのみ呼ばれる。
async function hasGatheringRelation(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  callerId: string,
  userId: string,
): Promise<boolean> {
  const { data: appliedToTheirs } = await supabase
    .from("gathering_applications")
    .select("id, gatherings!inner(host_id)")
    .eq("applicant_id", callerId)
    .eq("gatherings.host_id", userId)
    .limit(1);
  if ((appliedToTheirs?.length ?? 0) > 0) return true;

  const { data: theirsAppliedToMine } = await supabase
    .from("gathering_applications")
    .select("id, gatherings!inner(host_id)")
    .eq("applicant_id", userId)
    .eq("gatherings.host_id", callerId)
    .limit(1);
  if ((theirsAppliedToMine?.length ?? 0) > 0) return true;

  // グループトーク: 双方が同じ集まりの主催者または承認済みメンバーであれば関係ありとする。
  const [callerAccepted, callerHosted] = await Promise.all([
    supabase.from("gathering_applications").select("gathering_id").eq("applicant_id", callerId).eq("status", "accepted"),
    supabase.from("gatherings").select("id").eq("host_id", callerId),
  ]);
  const callerGatheringIds = Array.from(new Set([
    ...(callerAccepted.data ?? []).map((r: { gathering_id: string }) => r.gathering_id),
    ...(callerHosted.data ?? []).map((r: { id: string }) => r.id),
  ]));
  if (callerGatheringIds.length === 0) return false;

  const [targetAccepted, targetHosted] = await Promise.all([
    supabase.from("gathering_applications").select("gathering_id").eq("applicant_id", userId).eq("status", "accepted").in("gathering_id", callerGatheringIds),
    supabase.from("gatherings").select("id").eq("host_id", userId).in("id", callerGatheringIds),
  ]);
  return (targetAccepted.data?.length ?? 0) > 0 || (targetHosted.data?.length ?? 0) > 0;
}

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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ success: false, error: "unauthorized" }, 401);

    const { userId, title, body, data } = await req.json();
    if (!userId || !title || !body) {
      return json({ success: false, error: "userId, title, body are required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: callerData, error: callerError } = await userClient.auth.getUser();
    if (callerError || !callerData.user) return json({ success: false, error: "unauthorized" }, 401);
    const callerId = callerData.user.id;

    const supabase = createClient(supabaseUrl, serviceKey);

    // verify_jwtは「ログイン済みユーザーであること」しか保証しないため、これがないと
    // ログイン済みの誰もが任意のuserIdへ任意のtitle/bodyでプッシュ通知をなりすまし送信できてしまう。
    // 実際にこの関数を呼ぶのは「いいねを送った」「マッチした」「メッセージを送った」時だけなので、
    // 呼び出し元と対象ユーザーの間にlikesまたはmatchesの実際の関係があることを確認する。
    if (callerId !== userId) {
      const { data: relation, error: relationError } = await supabase
        .from("likes")
        .select("from_user_id")
        .eq("from_user_id", callerId)
        .eq("to_user_id", userId)
        .limit(1);
      if (relationError) throw relationError;

      let hasRelation = (relation?.length ?? 0) > 0;
      if (!hasRelation) {
        const { data: matchRows, error: matchError } = await supabase
          .from("matches")
          .select("id")
          .or(
            `and(user_a_id.eq.${callerId},user_b_id.eq.${userId}),and(user_a_id.eq.${userId},user_b_id.eq.${callerId})`,
          )
          .limit(1);
        if (matchError) throw matchError;
        hasRelation = (matchRows?.length ?? 0) > 0;
      }
      if (!hasRelation) {
        hasRelation = await hasGatheringRelation(supabase, callerId, userId);
      }

      if (!hasRelation) {
        return json({ success: false, error: "no relation to target user" }, 403);
      }
    }

    const jwt = await getApnsJWT();
    if (!jwt) {
      console.log("send-push: APNs secrets not configured, skipping");
      return json({ success: true, sent: 0, skipped: true });
    }

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
