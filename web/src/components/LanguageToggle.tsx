"use client";

import { useTranslation } from "@/lib/i18n/LanguageProvider";

// iOS版 AuthView の言語トグルボタンと同じ位置づけ: 日本語/英語をワンタップで切り替える。
export function LanguageToggle({ className = "" }: { className?: string }) {
  const { locale, setLocale } = useTranslation();
  return (
    <button
      type="button"
      onClick={() => setLocale(locale === "ja" ? "en" : "ja")}
      aria-label="Switch language"
      className={`rounded-full border border-[var(--line)] bg-white px-2.5 py-1 text-xs font-bold text-[var(--brand-purple-dark)] shadow-sm transition hover:bg-[var(--brand-purple-soft)] ${className}`}
    >
      {locale === "ja" ? "EN" : "JP"}
    </button>
  );
}
