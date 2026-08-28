"use client";

import { startTransition, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { NavBar } from "@/components/NavBar";
import { PageHeader } from "@/components/PageHeader";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { ageFromBirthday, type Match, type Message, type Profile } from "@/lib/types";

interface MatchedChat {
  match: Match;
  profile: Profile;
  photoUrl?: string;
  lastMessage?: Message;
  unreadCount: number;
}

function relativeTime(dateString: string, t: (key: string, vars?: Record<string, string | number>) => string): string {
  const diffMs = Date.now() - new Date(dateString).getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return t("chat.justNow");
  if (minutes < 60) return t("chat.minutesAgo", { n: minutes });
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return t("chat.hoursAgo", { n: hours });
  const days = Math.floor(hours / 24);
  return t("chat.daysAgo", { n: days });
}

export default function ChatListPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { t, locale } = useTranslation();
  const [matches, setMatches] = useState<MatchedChat[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }

    const { data: matchRows, error } = await supabase
      .from("matches")
      .select("*")
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`);
    if (error) {
      setErrorMessage(t("chat.loadError"));
      setIsLoading(false);
      return;
    }
    const allMatches = (matchRows ?? []) as Match[];

    const [{ data: hiddenRows }, { data: blockRows }] = await Promise.all([
      supabase.from("hidden_matches").select("match_id").eq("user_id", user.id),
      supabase.from("user_actions").select("actor_id, target_id").eq("action", "block").or(`actor_id.eq.${user.id},target_id.eq.${user.id}`),
    ]);
    const hiddenMatchIds = new Set((hiddenRows ?? []).map((r) => r.match_id as string));
    // iOS版 ChatManager と同じ: 自分がブロックした相手・自分をブロックした相手のどちらも
    // トーク一覧から消す(片方向だけだと、相手にブロックされた側の一覧に会話が残ってしまう)。
    const blockedCounterpartIds = new Set(
      (blockRows ?? []).map((r) => (r.actor_id === user.id ? (r.target_id as string) : (r.actor_id as string)))
    );

    const visibleMatches = allMatches.filter((m) => {
      if (hiddenMatchIds.has(m.id)) return false;
      const otherId = m.user_a_id === user.id ? m.user_b_id : m.user_a_id;
      return !blockedCounterpartIds.has(otherId);
    });
    if (visibleMatches.length === 0) {
      setMatches([]);
      setIsLoading(false);
      return;
    }

    const otherIds = visibleMatches.map((m) => (m.user_a_id === user.id ? m.user_b_id : m.user_a_id));
    const { data: profileRows } = await supabase.from("profiles").select("*").in("id", otherIds);
    const profilesById = new Map((profileRows ?? []).map((p) => [p.id, p as Profile]));
    const photoUrls = await loadMainPhotoUrls(supabase, otherIds);

    const { data: messageRows } = await supabase
      .from("messages")
      .select("*")
      .in(
        "match_id",
        visibleMatches.map((m) => m.id)
      )
      .order("created_at", { ascending: true });
    const lastMessageByMatch = new Map<string, Message>();
    const unreadCountByMatch = new Map<string, number>();
    for (const message of (messageRows ?? []) as Message[]) {
      lastMessageByMatch.set(message.match_id, message);
      if (message.sender_id !== user.id && !message.read_at) {
        unreadCountByMatch.set(message.match_id, (unreadCountByMatch.get(message.match_id) ?? 0) + 1);
      }
    }

    const result: MatchedChat[] = [];
    for (const match of visibleMatches) {
      const otherId = match.user_a_id === user.id ? match.user_b_id : match.user_a_id;
      const profile = profilesById.get(otherId);
      if (!profile) continue;
      result.push({
        match,
        profile,
        photoUrl: photoUrls[otherId],
        lastMessage: lastMessageByMatch.get(match.id),
        unreadCount: unreadCountByMatch.get(match.id) ?? 0,
      });
    }
    result.sort(
      (a, b) =>
        new Date(b.lastMessage?.created_at ?? 0).getTime() -
        new Date(a.lastMessage?.created_at ?? 0).getTime()
    );

    setMatches(result);
    setIsLoading(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router, supabase]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  function previewText(match: MatchedChat): string {
    if (!match.lastMessage) return t("chat.matched");
    if (match.lastMessage.body) return match.lastMessage.body;
    if (match.lastMessage.image_url) return t("chat.image");
    return t("chat.matched");
  }

  return (
    <div className="app-list-background flex min-h-screen flex-col">
    <main className="mx-auto w-full max-w-2xl flex-1 px-5 py-7 sm:px-8">
      <PageHeader title={t("chat.title")} />

      {isLoading ? (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="card flex items-center gap-3 p-3">
              <div className="h-14 w-14 shrink-0 animate-pulse rounded-full bg-[var(--paper-sunken)]" />
              <div className="flex-1 space-y-2">
                <div className="h-3.5 w-1/3 animate-pulse rounded bg-[var(--paper-sunken)]" />
                <div className="h-3 w-2/3 animate-pulse rounded bg-[var(--paper-sunken)]" />
              </div>
            </div>
          ))}
        </div>
      ) : errorMessage ? (
        <p className="card p-4 text-sm text-red-500">{errorMessage}</p>
      ) : matches.length === 0 ? (
        <div className="card flex flex-col items-center gap-2 py-16 text-center">
          <p className="text-3xl">💬</p>
          <p className="font-bold text-gray-600">{t("chat.empty")}</p>
          <p className="text-sm text-gray-400">{t("chat.emptyHint")}</p>
        </div>
      ) : (
        <div className="flex flex-col gap-2.5">
          {matches.map((match) => (
            <Link
              key={match.match.id}
              href={`/chat/${match.match.id}`}
              className={`card flex items-center gap-3 p-3 transition hover:-translate-y-0.5 ${
                match.unreadCount > 0 ? "border-[var(--brand-purple)]/40" : ""
              }`}
            >
              <div className="h-14 w-14 shrink-0 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
                {match.photoUrl && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={match.photoUrl} alt="" className="h-full w-full object-cover" />
                )}
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-baseline gap-2">
                  <p className="truncate font-bold text-[var(--brand-navy)]">{match.profile.name}</p>
                  <p className="text-xs text-gray-400">
                    {locale === "ja" ? `${ageFromBirthday(match.profile.birthday)}歳` : ageFromBirthday(match.profile.birthday)}
                  </p>
                </div>
                <p
                  className={`truncate text-sm ${
                    match.unreadCount > 0 ? "font-semibold text-gray-800" : "text-gray-400"
                  }`}
                >
                  {previewText(match)}
                </p>
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1.5">
                {match.lastMessage && (
                  <p className="text-xs text-gray-400">{relativeTime(match.lastMessage.created_at, t)}</p>
                )}
                {match.unreadCount > 0 && (
                  <span className="flex h-5 w-5 items-center justify-center rounded-full bg-[var(--brand-purple)] text-xs font-bold text-white">
                    {match.unreadCount}
                  </span>
                )}
              </div>
            </Link>
          ))}
        </div>
      )}
    </main>
    <NavBar />
    </div>
  );
}
