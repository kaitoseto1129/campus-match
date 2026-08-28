"use client";

import Link from "next/link";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import type { Profile } from "@/lib/types";

interface CompletenessItem {
  key: string;
  labelKey: string;
  href: string;
  isDone: boolean;
}

// iOS版 Profile.completeness(photoCount:) と同じ考え方の、6項目均等配分のプロフィール充実度。
export function computeCompleteness(profile: Profile, photoCount: number): CompletenessItem[] {
  return [
    { key: "photos", labelKey: "completeness.itemPhotos", href: "/profile/edit", isDone: photoCount >= 2 },
    {
      key: "description",
      labelKey: "completeness.itemDescription",
      href: "/profile/edit",
      isDone: (profile.description?.length ?? 0) >= 50,
    },
    { key: "tagline", labelKey: "completeness.itemTagline", href: "/profile/edit", isDone: Boolean(profile.tagline) },
    { key: "major", labelKey: "completeness.itemMajor", href: "/profile/edit", isDone: Boolean(profile.major) },
    {
      key: "languages",
      labelKey: "completeness.itemLanguages",
      href: "/profile/edit",
      isDone: profile.languages.length > 0,
    },
    {
      key: "hobbyCards",
      labelKey: "completeness.itemHobbyCards",
      href: "/profile/hobby-cards",
      isDone: profile.hobby_cards.length > 0,
    },
  ];
}

export function ProfileCompletenessCard({ profile, photoCount }: { profile: Profile; photoCount: number }) {
  const { t } = useTranslation();
  const items = computeCompleteness(profile, photoCount);
  const missing = items.filter((i) => !i.isDone);
  const percent = Math.round(((items.length - missing.length) / items.length) * 100);

  if (missing.length === 0) return null;

  return (
    <div className="card p-4">
      <div className="mb-2 flex items-center justify-between">
        <p className="text-sm font-bold text-gray-700">{t("completeness.title")}</p>
        <p className="text-sm font-bold text-[var(--brand-purple-dark)]">{percent}%</p>
      </div>
      <div className="mb-4 h-2 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
        <div className="h-full rounded-full bg-[var(--brand-purple)] transition-all" style={{ width: `${percent}%` }} />
      </div>
      <p className="mb-2 text-xs font-bold text-gray-400">{t("completeness.todoTitle")}</p>
      <div className="flex flex-col divide-y divide-[var(--paper-sunken)]">
        {missing.map((item) => (
          <div key={item.key} className="flex items-center justify-between py-2">
            <div className="flex items-center gap-2">
              <span className="h-3.5 w-3.5 shrink-0 rounded-full border-2 border-gray-300" />
              <span className="text-sm text-gray-600">{t(item.labelKey)}</span>
            </div>
            <Link href={item.href} className="shrink-0 text-xs font-bold text-[var(--brand-purple-dark)]">
              {item.key === "hobbyCards" ? t("completeness.set") : t("completeness.edit")}
            </Link>
          </div>
        ))}
      </div>
    </div>
  );
}
