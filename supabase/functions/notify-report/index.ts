// notify-report
//
// 通報が行われた時に、運営者のメールアドレスへ内容を通知する。
//
// 通報自体は reports テーブルに保存済みで、この通知は「運営が気づくのを早くする」ためのもの。
// そのためメール送信に失敗しても通報は失われず、クライアントにもエラーを返さない。
//
// 送信にはResend(https://resend.com)を使う。動かすには Supabase の
// Edge Functions > Secrets に以下を設定すること。
//   RESEND_API_KEY  … Resendで発行したAPIキー
//   REPORT_TO_EMAIL … 通報の通知先(未設定なら下記の既定値)
//   REPORT_FROM_EMAIL … 送信元(Resendで認証したドメインのアドレス。未設定ならResendの検証用アドレス)
// 未設定の間はメールを送らず、ログにだけ残して正常終了する。

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const DEFAULT_TO_EMAIL = "kaitoseto1129@gmail.com";
const DEFAULT_FROM_EMAIL = "onboarding@resend.dev";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
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

    // 通報者本人からの呼び出しであることを確認する。
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
    const reporterId = userData.user.id;

    const body = await req.json().catch(() => null);
    const reportedId = body?.reportedId;
    const reason = typeof body?.reason === "string" ? body.reason : "(理由の記載なし)";
    if (!reportedId || typeof reportedId !== "string") {
      return json({ error: "missing reportedId" }, 400);
    }

    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) {
      // 未設定でも通報自体は保存済みなので、成功として返す。
      console.log("RESEND_API_KEY not set; skipping report email", { reporterId, reportedId, reason });
      return json({ success: true, emailed: false });
    }

    // 通報された相手の情報を、運営が確認しやすいように添える。
    const serviceClient = createClient(supabaseUrl, serviceKey);
    const { data: reported } = await serviceClient
      .from("profiles")
      .select("name, university_id")
      .eq("id", reportedId)
      .maybeSingle();
    const { data: reporter } = await serviceClient
      .from("profiles")
      .select("name")
      .eq("id", reporterId)
      .maybeSingle();

    const html = `
      <h2>キャンパスマッチ 違反報告</h2>
      <table cellpadding="6" style="border-collapse:collapse">
        <tr><td><b>通報された人</b></td><td>${escapeHtml(reported?.name ?? "(不明)")}<br><code>${escapeHtml(reportedId)}</code></td></tr>
        <tr><td><b>通報した人</b></td><td>${escapeHtml(reporter?.name ?? "(不明)")}<br><code>${escapeHtml(reporterId)}</code></td></tr>
        <tr><td><b>理由</b></td><td>${escapeHtml(reason)}</td></tr>
        <tr><td><b>日時</b></td><td>${new Date().toISOString()}</td></tr>
      </table>
      <p>アプリの「通報管理(管理者)」画面からも確認・対応できます。</p>
    `;

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: Deno.env.get("REPORT_FROM_EMAIL") ?? DEFAULT_FROM_EMAIL,
        to: [Deno.env.get("REPORT_TO_EMAIL") ?? DEFAULT_TO_EMAIL],
        subject: `【キャンパスマッチ】違反報告: ${reported?.name ?? reportedId}`,
        html,
      }),
    });

    if (!response.ok) {
      // 送信に失敗しても通報は保存済みなので、クライアントには成功を返す。
      console.error("resend error", response.status, await response.text());
      return json({ success: true, emailed: false });
    }

    return json({ success: true, emailed: true });
  } catch (error) {
    console.error("notify-report error", error);
    return json({ success: true, emailed: false });
  }
});
