"use client";

import Link from "next/link";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { hobbyCardsFor } from "@/lib/hobbyCards";
import type { Profile } from "@/lib/types";

// 以前はここに「残りいいね」「会員ステータス」「アピール(ブースト)」「デイリーミッション」を
// 並べていたが、1対1のいいね・課金と一緒に廃止した。今は趣味カードだけを載せる。
export function MyPageExtras({
  profile,
  tutorialRef,
}: {
  profile: Profile;
  tutorialRef?: (id: string) => (el: HTMLElement | null) => void;
}) {
  const { t } = useTranslation();

  return (
    <section className="flex flex-col gap-4">
      <div ref={tutorialRef?.("myPageHobbyCards")} className="card p-4">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-sm font-bold">{t("myPageExtras.hobbyCards")}</p>
          <Link href="/profile/hobby-cards" className="text-xs font-bold text-[var(--brand-purple-dark)]">
            {profile.hobby_cards.length > 0 ? t("completeness.edit") : t("completeness.set")}
          </Link>
        </div>
        {profile.hobby_cards.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {hobbyCardsFor(profile.hobby_cards).map((card) => (
              <span key={card.id} className="rounded-full bg-purple-50 px-3 py-1 text-xs text-purple-600">
                {card.emoji} {card.title}
              </span>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
