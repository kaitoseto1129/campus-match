"use client";

import Link from "next/link";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

export interface MenuItem {
  href: string;
  emoji: string;
  /// iOS版 menuRow(icon:iconColor:) と同じ色を使う(以前は全項目が同じ薄いパステル円で、
  /// のっぺりした「AIが作った感」の一因になっていた)。
  color: string;
  labelKey: string;
}

const MAIN_ITEMS: MenuItem[] = [
  { href: "/profile/analytics", emoji: "📊", color: "#6366f1", labelKey: "myPage.analytics" },
  { href: "/profile/footprints", emoji: "👣", color: "var(--brand-orange)", labelKey: "myPage.footprints" },
  { href: "/profile/sent-likes", emoji: "👍", color: "var(--brand-purple)", labelKey: "myPage.sentLikes" },
  { href: "/profile/safety", emoji: "🛡️", color: "var(--brand-teal)", labelKey: "myPage.safetyGuide" },
  { href: "/profile/hidden", emoji: "🙈", color: "#8e8e93", labelKey: "myPage.hiddenList" },
  { href: "/profile/blocked", emoji: "🚫", color: "#1c1c1e", labelKey: "myPage.blockedList" },
];

export function MyPageMenu() {
  return (
    <div className="card flex flex-col divide-y divide-[#f1eff9]">
      {MAIN_ITEMS.map((item) => (
        <MenuRow key={item.href} {...item} />
      ))}
    </div>
  );
}

const SUPPORT_ITEMS: (MenuItem & { external?: string })[] = [
  { href: "/profile/contact", emoji: "✉️", color: "var(--brand-teal)", labelKey: "myPage.contact" },
  {
    href: "#",
    emoji: "📄",
    color: "var(--brand-purple)",
    labelKey: "myPage.terms",
    external: "https://kaitoseto1129.github.io/campus-match/terms.html",
  },
  {
    href: "#",
    emoji: "🔒",
    color: "#8e8e93",
    labelKey: "myPage.privacy",
    external: "https://kaitoseto1129.github.io/campus-match/privacy.html",
  },
];

export function MyPageSupport() {
  const { t } = useTranslation();
  return (
    <div>
      <p className="mb-2 px-1 text-sm font-bold text-gray-500">{t("myPage.support")}</p>
      <div className="card flex flex-col divide-y divide-[#f1eff9]">
        {SUPPORT_ITEMS.map((item) =>
          item.external ? (
            <a
              key={item.labelKey}
              href={item.external}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 p-4 transition hover:bg-[#faf9fe]"
            >
              <RowIcon emoji={item.emoji} color={item.color} />
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

function MenuRow({ href, emoji, color, labelKey }: MenuItem) {
  const { t } = useTranslation();
  return (
    <Link href={href} className="flex items-center gap-3 p-4 transition hover:bg-[#faf9fe]">
      <RowIcon emoji={emoji} color={color} />
      <span className="flex-1 text-sm text-gray-700">{t(labelKey)}</span>
      <span className="text-gray-300">›</span>
    </Link>
  );
}

function RowIcon({ emoji, color }: { emoji: string; color: string }) {
  return (
    <span
      className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-base"
      style={{ backgroundColor: color }}
    >
      {emoji}
    </span>
  );
}
