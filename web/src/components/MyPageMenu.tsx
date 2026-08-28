"use client";

import Link from "next/link";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

export interface MenuItem {
  href: string;
  emoji: string;
  labelKey: string;
}

const MAIN_ITEMS: MenuItem[] = [
  { href: "/profile/analytics", emoji: "📊", labelKey: "myPage.analytics" },
  { href: "/profile/footprints", emoji: "👣", labelKey: "myPage.footprints" },
  { href: "/profile/sent-likes", emoji: "💜", labelKey: "myPage.sentLikes" },
  { href: "/profile/safety", emoji: "🛡️", labelKey: "myPage.safetyGuide" },
  { href: "/profile/hidden", emoji: "🙈", labelKey: "myPage.hiddenList" },
  { href: "/profile/blocked", emoji: "🚫", labelKey: "myPage.blockedList" },
];

export function MyPageMenu() {
  return (
    <div className="card flex flex-col divide-y divide-[var(--paper-sunken)]">
      {MAIN_ITEMS.map((item) => (
        <MenuRow key={item.href} {...item} />
      ))}
    </div>
  );
}

const SUPPORT_ITEMS: (MenuItem & { external?: string })[] = [
  { href: "/profile/contact", emoji: "✉️", labelKey: "myPage.contact" },
  { href: "#", emoji: "📄", labelKey: "myPage.terms", external: "https://kaitoseto1129.github.io/campus-match/terms.html" },
  { href: "#", emoji: "🔒", labelKey: "myPage.privacy", external: "https://kaitoseto1129.github.io/campus-match/privacy.html" },
];

export function MyPageSupport() {
  const { t } = useTranslation();
  return (
    <div>
      <p className="mb-2 px-1 text-sm font-bold text-gray-500">{t("myPage.support")}</p>
      <div className="card flex flex-col divide-y divide-[var(--paper-sunken)]">
        {SUPPORT_ITEMS.map((item) =>
          item.external ? (
            <a
              key={item.labelKey}
              href={item.external}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 p-4 transition hover:bg-[var(--brand-purple-soft)]"
            >
              <RowIcon emoji={item.emoji} />
              <span className="flex-1 text-sm text-gray-700">{t(item.labelKey)}</span>
              <span className="text-gray-300">↗</span>
            </a>
          ) : (
            <MenuRow key={item.href} {...item} />
          )
        )}
      </div>
    </div>
  );
}

function MenuRow({ href, emoji, labelKey }: MenuItem) {
  const { t } = useTranslation();
  return (
    <Link href={href} className="flex items-center gap-3 p-4 transition hover:bg-[var(--brand-purple-soft)]">
      <RowIcon emoji={emoji} />
      <span className="flex-1 text-sm text-gray-700">{t(labelKey)}</span>
      <span className="text-gray-300">›</span>
    </Link>
  );
}

function RowIcon({ emoji }: { emoji: string }) {
  return (
    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[var(--paper-sunken)] text-base">
      {emoji}
    </span>
  );
}
