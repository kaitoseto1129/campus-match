"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { isProfileComplete, type Profile } from "@/lib/types";

// iOS版 NotificationCenterManager と同じ考え方: タブバーに出す2種類のバッジ
// (集まりの承認待ち件数・マイページのやることリストの有無)をまとめて取得する。
export function useNavBadges() {
  const [gatheringPending, setGatheringPending] = useState(0);
  const [hasProfileTodo, setHasProfileTodo] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const supabase = createClient();

    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user || cancelled) return;

      const { data: profileRow } = await supabase.from("profiles").select("*").eq("id", user.id).single();
      if (!cancelled && profileRow) setHasProfileTodo(!isProfileComplete(profileRow as Profile));

      const { data: hostedGatherings } = await supabase
        .from("gatherings")
        .select("id")
        .eq("host_id", user.id)
        .neq("status", "canceled");
      const gatheringIds = (hostedGatherings ?? []).map((g) => g.id as string);
      if (gatheringIds.length > 0) {
        const { count } = await supabase
          .from("gathering_applications")
          .select("id", { count: "exact", head: true })
          .in("gathering_id", gatheringIds)
          .eq("status", "pending");
        if (!cancelled) setGatheringPending(count ?? 0);
      }
    }

    load();

    // 応募が変化したら、そのつどバッジ数を数え直す。
    const channel = supabase
      .channel(`nav-badges:${Math.random()}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "gathering_applications" }, load)
      .subscribe();

    return () => {
      cancelled = true;
      supabase.removeChannel(channel);
    };
  }, []);

  return { gatheringPending, hasProfileTodo };
}
