"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { LanguageToggle } from "@/components/LanguageToggle";

// 4つの主要画面(探す・集まり・トーク・マイページ)で共通のヘッダー。
// 左に画面タイトル、右に画面固有のアクション、中央にはどの画面でも
// 常にアプリアイコンを置く(ブランドの一貫性のため、ログイン画面と同じCMアイコン)。
export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="relative mb-6 flex items-center justify-between gap-3">
      <div className="min-w-0">
        <h1 className="text-2xl font-bold text-[var(--brand-navy)]">{title}</h1>
        {subtitle && <p className="mt-0.5 truncate text-sm text-[var(--ink-muted)]">{subtitle}</p>}
      </div>

      <Link
        href="/discover"
        aria-label="キャンマッチ"
        className="absolute top-1/2 left-1/2 flex h-9 w-9 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-xl bg-[var(--brand-purple)] text-xs font-extrabold text-white"
      >
        CM
      </Link>

      <div className="flex shrink-0 items-center gap-2">
        <LanguageToggle />
        {action}
      </div>
    </div>
  );
}
