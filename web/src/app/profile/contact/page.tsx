"use client";

import { useState } from "react";
import { DetailHeader } from "@/components/DetailHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

const CONTACT_EMAIL = "kaitoseto1129@gmail.com";
const TOPICS = [1, 2, 3, 4] as const;

export default function ContactPage() {
  const { t } = useTranslation();
  const [copied, setCopied] = useState(false);

  async function handleCopy() {
    await navigator.clipboard.writeText(CONTACT_EMAIL);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("contact.title")} />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        <p className="mb-5 text-sm text-gray-500">{t("contact.intro")}</p>

        <div className="card mb-5 p-4">
          <p className="mb-3 text-center font-bold text-[var(--brand-navy)]">{CONTACT_EMAIL}</p>
          <div className="flex flex-col gap-2">
            <a
              href={`mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent("キャンマッチ お問い合わせ")}`}
              className="btn-primary w-full py-3 text-center"
            >
              {t("contact.emailButton")}
            </a>
            <button onClick={handleCopy} className="btn-secondary w-full py-3">
              {copied ? t("contact.copied") : t("contact.copyButton")}
            </button>
          </div>
        </div>

        <div className="card p-4">
          <p className="mb-2 text-sm font-bold text-gray-700">{t("contact.topicsTitle")}</p>
          <ul className="flex flex-col gap-1.5">
            {TOPICS.map((n) => (
              <li key={n} className="text-sm text-gray-500">
                ・{t(`contact.topic${n}`)}
              </li>
            ))}
          </ul>
        </div>
      </main>
    </div>
  );
}
