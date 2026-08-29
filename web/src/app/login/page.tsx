"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { LanguageToggle } from "@/components/LanguageToggle";
import { AppStoreButton } from "@/components/AppStoreButton";

type Mode = "signup" | "signin";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [mode, setMode] = useState<Mode>("signup");
  const [displayName, setDisplayName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isPasswordVisible, setIsPasswordVisible] = useState(false);
  const [validDomains, setValidDomains] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isAlreadyRegistered, setIsAlreadyRegistered] = useState(false);

  // メール確認コード入力待ちの状態(Supabaseの「Confirm email」がONのため、
  // サインアップ直後はまだセッションが発行されず、確認コードの検証が必要)。
  const [pendingVerificationEmail, setPendingVerificationEmail] = useState<string | null>(null);
  const [verificationCode, setVerificationCode] = useState("");
  const [isResending, setIsResending] = useState(false);
  const [resendMessage, setResendMessage] = useState<string | null>(null);
  const [resendCooldown, setResendCooldown] = useState(0);

  // iOS版 AuthView.forgotPasswordSheet と同じ: パスワード再設定メールの送信フロー。
  const [showingForgotPassword, setShowingForgotPassword] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [isSendingReset, setIsSendingReset] = useState(false);
  const [resetErrorMessage, setResetErrorMessage] = useState<string | null>(null);
  const [resetSent, setResetSent] = useState(false);

  async function handleSendPasswordReset() {
    if (!resetEmail.includes("@") || isSendingReset) return;
    setIsSendingReset(true);
    setResetErrorMessage(null);
    const { error } = await supabase.auth.resetPasswordForEmail(resetEmail.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    setIsSendingReset(false);
    if (error) {
      setResetErrorMessage(t("login.resetSendError"));
      return;
    }
    setResetSent(true);
  }

  useEffect(() => {
    supabase
      .from("universities")
      .select("domain")
      .then(({ data }) => {
        if (data) setValidDomains(data.map((row) => row.domain as string));
      });
  }, [supabase]);

  useEffect(() => {
    if (resendCooldown <= 0) return;
    const timer = setInterval(() => setResendCooldown((c) => Math.max(0, c - 1)), 1000);
    return () => clearInterval(timer);
  }, [resendCooldown]);

  const trimmedEmail = email.trim();

  // 早稲田大学のように「@ruri.waseda.jp」のようなサブドメインでメールを発行する
  // 大学もあるため、完全一致だけでなくサブドメイン一致も許可する
  // (サーバー側のcheck_university_emailと同じ判定)。
  const isEmailDomainValid =
    mode !== "signup" ||
    validDomains.length === 0 ||
    validDomains.some((domain) => {
      const d = domain.toLowerCase();
      const lowered = trimmedEmail.toLowerCase();
      return lowered.endsWith(`@${d}`) || lowered.endsWith(`.${d}`);
    });

  const isFormValid =
    password.length >= 6 &&
    trimmedEmail.includes("@") &&
    isEmailDomainValid &&
    (mode === "signin" || displayName.length > 0);

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") handleSubmit();
  }

  async function handleSubmit() {
    if (!isFormValid || isLoading) return;
    setIsLoading(true);
    setErrorMessage(null);
    setIsAlreadyRegistered(false);

    if (mode === "signin") {
      const { error } = await supabase.auth.signInWithPassword({
        email: trimmedEmail,
        password,
      });
      if (error) {
        if (error.code === "email_not_confirmed") {
          setPendingVerificationEmail(trimmedEmail);
          setErrorMessage(t("login.emailNotConfirmed"));
        } else {
          setErrorMessage(t("login.wrongCredentials"));
        }
      } else {
        router.push("/");
        router.refresh();
      }
    } else {
      const { data, error } = await supabase.auth.signUp({
        email: trimmedEmail,
        password,
        options: { data: { display_name: displayName } },
      });
      if (error) {
        if (
          error.code === "user_already_exists" ||
          error.message.toLowerCase().includes("already registered") ||
          error.message.toLowerCase().includes("already exists")
        ) {
          setErrorMessage(t("login.alreadyRegistered"));
          setIsAlreadyRegistered(true);
        } else {
          setErrorMessage(`${error.message} (${error.code ?? "unknown"})`);
        }
      } else if (!data.session) {
        setPendingVerificationEmail(trimmedEmail);
      } else {
        router.push("/");
        router.refresh();
      }
    }
    setIsLoading(false);
  }

  async function handleVerify() {
    if (!pendingVerificationEmail || verificationCode.trim().length === 0 || isLoading) return;
    setIsLoading(true);
    setErrorMessage(null);
    const { error } = await supabase.auth.verifyOtp({
      email: pendingVerificationEmail,
      token: verificationCode.trim(),
      type: "signup",
    });
    if (error) {
      setErrorMessage(t("login.otpError"));
    } else {
      router.push("/");
      router.refresh();
    }
    setIsLoading(false);
  }

  async function handleResend() {
    if (!pendingVerificationEmail || isResending || resendCooldown > 0) return;
    setIsResending(true);
    setResendMessage(null);
    const { error } = await supabase.auth.resend({
      type: "signup",
      email: pendingVerificationEmail,
    });
    setIsResending(false);
    if (error) {
      setResendMessage(t("login.otpResendError"));
    } else {
      setResendMessage(t("login.otpResendSent"));
      setResendCooldown(30);
    }
  }

  if (pendingVerificationEmail) {
    return (
      <div className="brand-gradient relative flex min-h-screen items-center justify-center px-6 py-10">
        <LanguageToggle className="absolute top-5 right-5" />
        <div className="card w-full max-w-sm p-8">
          <div className="mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-2xl brand-gradient text-2xl font-bold text-white shadow-lg">
            CM
          </div>
          <h1 className="mb-2 text-center text-lg font-bold">{t("login.otpTitle")}</h1>
          <p className="mb-6 text-center text-sm text-gray-500">
            <span className="font-semibold text-gray-700">{pendingVerificationEmail}</span> {t("login.otpDescSuffix")}
          </p>
          <input
            value={verificationCode}
            onChange={(e) => setVerificationCode(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleVerify();
            }}
            placeholder={t("login.otpPlaceholder")}
            inputMode="numeric"
            autoComplete="one-time-code"
            className="input mb-4 text-center text-lg tracking-[0.3em]"
          />
          {errorMessage && <p className="mb-4 text-sm text-red-500">{errorMessage}</p>}
          <button
            onClick={handleVerify}
            disabled={isLoading}
            className="btn-primary w-full py-3.5"
          >
            {isLoading ? t("login.otpVerifying") : t("login.otpVerify")}
          </button>
          <button
            onClick={handleResend}
            disabled={isResending || resendCooldown > 0}
            className="mt-4 w-full text-center text-sm font-semibold text-[var(--brand-purple-dark)] disabled:opacity-50"
          >
            {isResending
              ? t("login.otpResending")
              : resendCooldown > 0
                ? `${t("login.otpResend")} (${resendCooldown}s)`
                : t("login.otpResend")}
          </button>
          {resendMessage && <p className="mt-2 text-center text-xs text-gray-500">{resendMessage}</p>}
          <button
            onClick={() => {
              setPendingVerificationEmail(null);
              setVerificationCode("");
              setErrorMessage(null);
            }}
            className="mt-4 w-full text-center text-sm font-semibold text-gray-400 hover:text-gray-600"
          >
            {t("login.otpBack")}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="brand-gradient relative flex min-h-screen items-center justify-center px-6 py-10">
      <LanguageToggle className="absolute top-5 right-5" />
      <div className="card w-full max-w-sm p-8">
        <div className="mb-7 text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl brand-gradient text-2xl font-bold text-white shadow-lg shadow-purple-300/50">
            CM
          </div>
          <h1 className="text-xl font-bold text-[var(--brand-navy)]">{t("login.appName")}</h1>
          <p className="mt-1 text-sm text-gray-400">{t("login.tagline")}</p>
          <div className="mt-4">
            <AppStoreButton />
          </div>
        </div>

        <div className="mb-5 flex rounded-full bg-[#f1eff9] p-1">
          <button
            onClick={() => setMode("signup")}
            className={`flex-1 rounded-full py-2 text-sm font-bold transition ${
              mode === "signup" ? "bg-white text-[var(--brand-purple-dark)] shadow" : "text-gray-400"
            }`}
          >
            {t("login.signup")}
          </button>
          <button
            onClick={() => setMode("signin")}
            className={`flex-1 rounded-full py-2 text-sm font-bold transition ${
              mode === "signin" ? "bg-white text-[var(--brand-purple-dark)] shadow" : "text-gray-400"
            }`}
          >
            {t("login.signin")}
          </button>
        </div>

        <div className="flex flex-col gap-3">
          {mode === "signup" && (
            <input
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t("login.displayName")}
              autoComplete="name"
              className="input"
            />
          )}
          <div>
            <input
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t("login.email")}
              type="email"
              autoComplete="email"
              className="input"
            />
            {mode === "signup" && (
              <p className="mt-1.5 px-1 text-xs text-gray-400">{t("login.domainHint")}</p>
            )}
          </div>
          <div>
            <div className="relative">
              <input
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder={t("login.password")}
                type={isPasswordVisible ? "text" : "password"}
                autoComplete={mode === "signup" ? "new-password" : "current-password"}
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
            {mode === "signup" && password.length > 0 && (
              <p className={`mt-1.5 px-1 text-xs ${password.length >= 6 ? "text-[var(--brand-teal)]" : "text-gray-400"}`}>
                {password.length >= 6 ? t("login.passwordOk") : t("login.passwordHintShort", { n: 6 - password.length })}
              </p>
            )}
          </div>
        </div>

        {mode === "signin" && (
          <button
            onClick={() => {
              setResetEmail(trimmedEmail);
              setResetErrorMessage(null);
              setResetSent(false);
              setShowingForgotPassword(true);
            }}
            className="mt-3 text-xs font-semibold text-gray-400 hover:text-gray-600"
          >
            {t("login.forgotPassword")}
          </button>
        )}

        {errorMessage && (
          <div className="mt-4 text-sm text-red-500">
            <p>{errorMessage}</p>
            {isAlreadyRegistered && (
              <button
                onClick={() => {
                  setMode("signin");
                  setErrorMessage(null);
                  setIsAlreadyRegistered(false);
                }}
                className="mt-1 font-bold text-[var(--brand-purple-dark)] underline"
              >
                {t("login.switchToSignin")}
              </button>
            )}
          </div>
        )}

        <button
          onClick={handleSubmit}
          disabled={!isFormValid || isLoading}
          className="btn-primary mt-6 w-full py-3.5"
        >
          {isLoading ? t("login.submitting") : mode === "signup" ? t("login.submitSignup") : t("login.submitSignin")}
        </button>

        <p className="mt-6 text-center text-[11px] text-gray-400">
          {t("login.termsAgreePrefix")}
          <a
            href="https://kaitoseto1129.github.io/campus-match/terms.html"
            target="_blank"
            rel="noopener noreferrer"
            className="mx-1 underline hover:text-gray-600"
          >
            {t("login.terms")}
          </a>
          {t("login.and")}
          <a
            href="https://kaitoseto1129.github.io/campus-match/privacy.html"
            target="_blank"
            rel="noopener noreferrer"
            className="mx-1 underline hover:text-gray-600"
          >
            {t("login.privacy")}
          </a>
          {t("login.termsAgreeSuffix")}
        </p>
      </div>

      {showingForgotPassword && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/45 px-6 backdrop-blur-sm">
          <div className="card w-full max-w-sm p-7">
            <h2 className="mb-2 text-lg font-bold text-[var(--brand-navy)]">{t("login.resetTitle")}</h2>
            {resetSent ? (
              <>
                <p className="mb-6 text-sm text-gray-500">
                  <span className="font-semibold text-gray-700">{resetEmail}</span>{" "}
                  {t("login.resetSentDescSuffix")}
                </p>
                <button
                  onClick={() => setShowingForgotPassword(false)}
                  className="btn-primary w-full py-3"
                >
                  {t("common.close")}
                </button>
              </>
            ) : (
              <>
                <p className="mb-4 text-sm text-gray-500">{t("login.resetDesc")}</p>
                <input
                  value={resetEmail}
                  onChange={(e) => setResetEmail(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSendPasswordReset();
                  }}
                  placeholder={t("login.email")}
                  type="email"
                  autoComplete="email"
                  className="input mb-3"
                />
                {resetErrorMessage && <p className="mb-3 text-sm text-red-500">{resetErrorMessage}</p>}
                <div className="flex gap-3">
                  <button
                    onClick={() => setShowingForgotPassword(false)}
                    className="btn-secondary flex-1 py-3"
                  >
                    {t("common.cancel")}
                  </button>
                  <button
                    onClick={handleSendPasswordReset}
                    disabled={!resetEmail.includes("@") || isSendingReset}
                    className="btn-primary flex-1 py-3"
                  >
                    {isSendingReset ? t("common.sending") : t("common.send")}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
