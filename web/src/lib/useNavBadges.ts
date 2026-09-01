"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { isProfileComplete, type Profile } from "@/lib/types";

// iOS版 NotificationCenterManager と同じ考え方: タブバーに出す3種類のバッジ
// (トークの未読数・集まりの承認待ち件数・マイページのやることリストの有無)をまとめて取得する。
export function useNavBadges() {
  const [chatUnread, setChatUnread] = useState(0);
  const [gatheringPending, setGatheringPending] = useState(0);
  const [likesReceived, setLikesReceived] = useState(0);
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

      const { data: matchRows } = await supabase
        .from("matches")
        .select("id, user_a_id, user_b_id")
        .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`);
      const matchIds = (matchRows ?? []).map((m) => m.id as string);
      const matchedPartnerIds = new Set(
        (matchRows ?? []).map((m) => (m.user_a_id === user.id ? (m.user_b_id as string) : (m.user_a_id as string)))
      );

      const { data: receivedLikeRows } = await supabase
        .from("likes")
        .select("from_user_id")
        .eq("to_user_id", user.id);
      const pendingLikes = (receivedLikeRows ?? []).filter(
        (r) => !matchedPartnerIds.has(r.from_user_id as string)
      );
      if (!cancelled) setLikesReceived(pendingLikes.length);
      if (matchIds.length > 0) {
        const { count } = await supabase
          .from("messages")
          .select("id", { count: "exact", head: true })
          .in("match_id", matchIds)
          .neq("sender_id", user.id)
          .is("read_at", null)
          .is("deleted_at", null);
        if (!cancelled) setChatUnread(count ?? 0);
      }

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

    // メッセージ・応募のいずれかが変化したら、そのつどバッジ数を数え直す。
    const channel = supabase
      .channel(`nav-badges:${Math.random()}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "messages" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "gathering_applications" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "likes" }, load)
      .on("postgres_changes", { event: "*", schema: "public", table: "matches" }, load)
      .subscribe();

    return () => {
      cancelled = true;
      supabase.removeChannel(channel);
    };
  }, []);

  return { chatUnread, gatheringPending, likesReceived, hasProfileTodo };
}
