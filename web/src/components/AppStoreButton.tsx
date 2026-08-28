"use client";

import { useState } from "react";
import { APP_STORE_URL } from "@/lib/constants";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

// App Store審査完了までは遷移先が無いため、押しても「近日公開」を一瞬表示するだけにする。
// APP_STORE_URLが設定され次第、自動的に実際のリンクとして機能する。
export function AppStoreButton({ className = "" }: { className?: string }) {
  const { t } = useTranslation();
  const [showComingSoon, setShowComingSoon] = useState(false);

  if (APP_STORE_URL) {
    return (
      <a
        href={APP_STORE_URL}
        target="_blank"
        rel="noopener noreferrer"
        className={`inline-flex items-center gap-1.5 rounded-full border border-[var(--line)] bg-white px-4 py-2 text-sm font-bold text-[var(--brand-purple-dark)] shadow-sm transition hover:bg-[var(--brand-purple-soft)] ${className}`}
      >
        📱 {t("appStore.button")}
      </a>
    );
  }

  return (
    <div className={`relative inline-block ${className}`}>
      <button
        type="button"
        onClick={() => {
          setShowComingSoon(true);
          setTimeout(() => setShowComingSoon(false), 2000);
        }}
        className="inline-flex items-center gap-1.5 rounded-full border border-[var(--line)] bg-white px-4 py-2 text-sm font-bold text-[var(--brand-purple-dark)] shadow-sm transition hover:bg-[var(--brand-purple-soft)]"
      >
        📱 {t("appStore.button")}
      </button>
      {showComingSoon && (
        <div className="absolute bottom-full left-1/2 mb-2 -translate-x-1/2 rounded-lg bg-[var(--brand-navy)] px-3 py-1.5 text-xs font-bold whitespace-nowrap text-white shadow-lg">
          {t("appStore.comingSoon")}
        </div>
      )}
    </div>
  );
}
