"use client";

import { DetailHeader } from "@/components/DetailHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

const ITEMS = [1, 2, 3, 4] as const;

export default function SafetyGuidePage() {
  const { t } = useTranslation();
  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("safety.title")} />
      <main className="mx-auto flex w-full max-w-lg flex-col gap-3 px-5 py-6 sm:px-8">
        {ITEMS.map((n) => (
          <div key={n} className="card p-4">
            <p className="mb-1.5 font-bold text-[var(--brand-navy)]">{t(`safety.item${n}Title`)}</p>
            <p className="text-sm text-gray-500">{t(`safety.item${n}Body`)}</p>
          </div>
        ))}
      </main>
    </div>
  );
}
