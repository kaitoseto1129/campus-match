"use client";

import { useRouter } from "next/navigation";
import type { ReactNode } from "react";

// マイページのプッシュ画面(プロフィール編集・分析・足あと等)で共通の、
// 戻るボタン+タイトルのヘッダー。/discover/[id] と同じパターン。
export function DetailHeader({ title, action }: { title: string; action?: ReactNode }) {
  const router = useRouter();
  return (
    <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-[var(--line)] bg-white/95 px-4 py-3 backdrop-blur-md">
      <button onClick={() => router.back()} aria-label="戻る" className="text-xl text-[var(--brand-purple)]">
        ‹
      </button>
      <p className="flex-1 truncate font-bold text-[var(--brand-navy)]">{title}</p>
      {action}
    </header>
  );
}
