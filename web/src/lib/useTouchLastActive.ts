"use client";

import { useEffect } from "react";
import { createClient } from "@/lib/supabase/client";

const THROTTLE_MS = 60_000;
const STORAGE_KEY = "cammatch:lastActiveTouchedAt";

// iOS版 AuthManager.touchLastActive() と同じ: 画面を開くたびに profiles.last_active_at を
// 更新する。これが無いと、Web版ユーザーは「探す」の並び順で常に沈み、オンライン判定
// (is_user_online、5分以内の活動を見る)が常にfalseになり、ログインボーナスミッションも
// 初日以降二度と達成できなくなる。連続ナビゲーションで無駄打ちしないよう軽くスロットルする。
export function useTouchLastActive() {
  useEffect(() => {
    const lastTouched = Number(sessionStorage.getItem(STORAGE_KEY) ?? 0);
    if (Date.now() - lastTouched < THROTTLE_MS) return;

    const supabase = createClient();
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) return;
      sessionStorage.setItem(STORAGE_KEY, String(Date.now()));
      supabase
        .from("profiles")
        .update({ last_active_at: new Date().toISOString() })
        .eq("id", user.id)
        .then(({ error }) => {
          if (error) console.error("touch last active error", error);
        });
    });
  }, []);
}
