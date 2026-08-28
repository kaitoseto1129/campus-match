"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { LanguageToggle } from "@/components/LanguageToggle";

// メール内のパスワード再設定リンクから遷移してくるページ。
// リンクのURLフラグメント(#access_token=...&type=recovery)はSupabaseクライアントが
// 読み込み時に自動でセッションへ交換するため、ここでは新しいパスワードを入力させるだけでよい。
export default function ResetPasswordPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [isCheckingSession, setIsCheckingSession] = useState(true);
  const [hasValidSession, setHasValidSession] = useState(false);
  const [password, setPassword] = useState("");
  const [isPasswordVisible, setIsPasswordVisible] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isDone, setIsDone] = useState(false);

  useEffect(() => {
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "PASSWORD_RECOVERY" || session) {
        setHasValidSession(true);
        setIsCheckingSession(false);
      }
    });
    // 既にセッション交換が完了している場合(onAuthStateChangeの発火より前に読み込みが終わっていた場合)に備える。
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        setHasValidSession(true);
      }
      setIsCheckingSession(false);
    });
    return () => subscription.unsubscribe();
  }, [supabase]);

  async function handleSave() {
    if (password.length < 6 || isSaving) return;
    setIsSaving(true);
    setErrorMessage(null);
    const { error } = await supabase.auth.updateUser({ password });
    setIsSaving(false);
    if (error) {
      setErrorMessage(t("resetPassword.updateError"));
      return;
    }
    setIsDone(true);
  }

  return (
    <div className="brand-gradient relative flex min-h-screen items-center justify-center px-6 py-10">
      <LanguageToggle className="absolute top-5 right-5" />
      <div className="card w-full max-w-sm p-8">
        <div className="mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-2xl brand-gradient text-2xl font-bold text-white shadow-lg">
          CM
        </div>
        <h1 className="mb-6 text-center text-lg font-bold text-[var(--brand-navy)]">{t("resetPassword.title")}</h1>

        {isCheckingSession ? (
          <div className="flex justify-center py-6">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
          </div>
        ) : isDone ? (
          <>
            <p className="mb-6 text-center text-sm text-gray-500">{t("resetPassword.done")}</p>
            <button onClick={() => router.push("/login")} className="btn-primary w-full py-3.5">
              {t("resetPassword.toLogin")}
            </button>
          </>
        ) : !hasValidSession ? (
          <>
            <p className="mb-6 text-center text-sm text-gray-500">{t("resetPassword.invalid")}</p>
            <button onClick={() => router.push("/login")} className="btn-primary w-full py-3.5">
              {t("resetPassword.toLogin")}
            </button>
          </>
        ) : (
          <>
            <div className="relative mb-2">
              <input
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleSave();
                }}
                placeholder={t("login.newPassword")}
                type={isPasswordVisible ? "text" : "password"}
                autoComplete="new-password"
                className="input pr-11"
              />
              <button
                type="button"
                onClick={() => setIsPasswordVisible((v) => !v)}
                aria-label={isPasswordVisible ? t("login.hide") : t("login.show")}
                className="absolute top-1/2 right-3 -translate-y-1/2 text-xs font-semibold text-gray-400 hover:text-gray-600"
              >
                {isPasswordVisible ? t("login.hide") : t("login.show")}
              </button>
            </div>
            {password.length > 0 && (
              <p className={`mb-4 px-1 text-xs ${password.length >= 6 ? "text-[var(--brand-teal)]" : "text-gray-400"}`}>
                {password.length >= 6 ? t("login.passwordOk") : t("login.passwordHintShort", { n: 6 - password.length })}
              </p>
            )}
            {errorMessage && <p className="mb-4 text-sm text-red-500">{errorMessage}</p>}
            <button
              onClick={handleSave}
              disabled={password.length < 6 || isSaving}
              className="btn-primary w-full py-3.5"
            >
              {isSaving ? t("resetPassword.updating") : t("resetPassword.updateButton")}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
