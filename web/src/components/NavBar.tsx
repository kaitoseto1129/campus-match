"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useNavBadges } from "@/lib/useNavBadges";
import { useTouchLastActive } from "@/lib/useTouchLastActive";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

const TABS = [
  { href: "/discover", labelKey: "nav.discover", icon: SearchIcon },
  { href: "/gatherings", labelKey: "nav.gatherings", icon: PeopleIcon },
  { href: "/chat", labelKey: "nav.chat", icon: ChatIcon },
  { href: "/profile", labelKey: "nav.profile", icon: PersonIcon },
] as const;

export function NavBar() {
  const pathname = usePathname();
  const { chatUnread, gatheringPending, hasProfileTodo } = useNavBadges();
  const { t } = useTranslation();
  useTouchLastActive();

  const badgeFor: Record<(typeof TABS)[number]["href"], number> = {
    "/discover": 0,
    "/gatherings": gatheringPending,
    "/chat": chatUnread,
    "/profile": 0,
  };

  return (
    <nav className="sticky bottom-0 z-40 border-t border-[#e5e5ea] bg-white/95 backdrop-blur-md">
      <div className="mx-auto flex max-w-2xl pt-2 pb-1">
        {TABS.map((tab) => {
          const isActive = pathname.startsWith(tab.href);
          const Icon = tab.icon;
          const badge = badgeFor[tab.href];
          const showTodoDot = tab.href === "/profile" && hasProfileTodo;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`flex flex-1 flex-col items-center gap-1 py-1 transition ${
                isActive ? "text-[var(--brand-purple)]" : "text-[#8e8e93]"
              }`}
            >
              <span className="relative flex h-9 w-9 items-center justify-center">
                <span
                  className={`flex h-9 w-9 items-center justify-center rounded-full transition-all ${
                    isActive ? "bg-[var(--brand-purple)] text-white shadow-sm shadow-purple-300/60" : ""
                  } ${showTodoDot && !isActive ? "bg-[var(--brand-purple)]/12" : ""}`}
                >
                  <Icon bold={isActive} />
                </span>
                {badge > 0 && (
                  <span className="absolute -top-1 -right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[var(--brand-pink)] px-1 text-[10px] font-bold text-white shadow">
                    {badge > 99 ? "99+" : badge}
                  </span>
                )}
                {badge === 0 && showTodoDot && (
                  <span className="absolute top-0 right-0 h-2.5 w-2.5 rounded-full bg-[var(--brand-purple)] ring-2 ring-white" />
                )}
              </span>
              <span className={`text-[10px] ${isActive ? "font-bold" : "font-semibold"}`}>{t(tab.labelKey)}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

interface IconProps {
  bold?: boolean;
}

function iconProps(bold?: boolean) {
  return {
    width: 20,
    height: 20,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: bold ? 2.5 : 2.1,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
}

function SearchIcon({ bold }: IconProps) {
  return (
    <svg {...iconProps(bold)}>
      <circle cx="11" cy="11" r="7" />
      <path d="M21 21l-4.3-4.3" />
    </svg>
  );
}

function PeopleIcon({ bold }: IconProps) {
  return (
    <svg {...iconProps(bold)}>
      <path d="M17 20v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1" />
      <circle cx="10" cy="7" r="3.5" />
      <path d="M22 20v-1a3.5 3.5 0 0 0-2.5-3.35" />
      <path d="M16 3.65a3.5 3.5 0 0 1 0 6.7" />
    </svg>
  );
}

function ChatIcon({ bold }: IconProps) {
  return (
    <svg {...iconProps(bold)}>
      <path d="M21 12a8 8 0 0 1-8 8H6l-3 3v-4.5A8 8 0 1 1 21 12Z" />
    </svg>
  );
}

function PersonIcon({ bold }: IconProps) {
  return (
    <svg {...iconProps(bold)}>
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1" />
    </svg>
  );
}
