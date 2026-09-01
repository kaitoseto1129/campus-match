"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { PageHeader } from "@/components/PageHeader";
import { NavBar } from "@/components/NavBar";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { ageFromBirthday, type Match, type Profile } from "@/lib/types";

interface ReceivedLikeRow {
  otherUserId: string;
  likeId: string;
  createdAt: string;
  profile: Profile;
  photoUrl?: string;
}

export default function LikesPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [myId, setMyId] = useState<string | null>(null);
  const [rows, setRows] = useState<ReceivedLikeRow[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [thankedIds, setThankedIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }
      setMyId(user.id);

      const [{ data: receivedLikeRows }, { data: matchRows }] = await Promise.all([
        supabase
          .from("likes")
          .select("id, from_user_id, created_at")
          .eq("to_user_id", user.id)
          .order("created_at", { ascending: false }),
        supabase.from("matches").select("*").or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`),
      ]);
      if (cancelled) return;

      const matches = (matchRows ?? []) as Match[];
      const matchedPartnerIds = new Set(
        matches.map((m) => (m.user_a_id === user.id ? m.user_b_id : m.user_a_id))
      );

      // マッチ済みの相手を除いた、まだ「ありがとう」を返せる届いたいいねだけを対象にする。
      const pending = (receivedLikeRows ?? []).filter(
        (r) => !matchedPartnerIds.has(r.from_user_id as string)
      );

      const otherIds = pending.map((r) => r.from_user_id as string);
      if (otherIds.length === 0) {
        setRows([]);
        setIsLoading(false);
        return;
      }

      const [{ data: profileRows }, photoUrls] = await Promise.all([
        supabase.from("profiles").select("*").in("id", otherIds),
        loadMainPhotoUrls(supabase, otherIds),
      ]);
      if (cancelled) return;

      const profilesById = new Map((profileRows ?? []).map((p) => [p.id, p as Profile]));

      const result: ReceivedLikeRow[] = pending
        .map((r): ReceivedLikeRow | null => {
          const profile = profilesById.get(r.from_user_id as string);
          if (!profile) return null;
          return {
            otherUserId: r.from_user_id as string,
            likeId: r.id as string,
            createdAt: r.created_at as string,
            profile,
            photoUrl: photoUrls[r.from_user_id as string],
          };
        })
        .filter((r): r is ReceivedLikeRow => r !== null);

      setRows(result);
      setIsLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [router, supabase]);

  async function handleThanks(row: ReceivedLikeRow) {
    if (!myId || thankedIds.has(row.likeId)) return;
    setThankedIds((prev) => new Set(prev).add(row.likeId));
    const [userAId, userBId] = myId < row.otherUserId ? [myId, row.otherUserId] : [row.otherUserId, myId];
    const { error } = await supabase
      .from("matches")
      .insert({ like_id: row.likeId, user_a_id: userAId, user_b_id: userBId });
    if (error) {
      // 失敗したら再度押せるように戻す。
      setThankedIds((prev) => {
        const next = new Set(prev);
        next.delete(row.likeId);
        return next;
      });
    } else {
      setRows((prev) => prev.filter((r) => r.likeId !== row.likeId));
    }
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  return (
    <div className="app-list-background flex min-h-screen flex-col">
      <main className="mx-auto w-full max-w-2xl flex-1 px-5 py-7 sm:px-8">
        <PageHeader title={t("likes.title")} />

        {rows.length === 0 ? (
          <div className="card flex flex-col items-center gap-2 py-16 text-center">
            <p className="text-3xl">👍</p>
            <p className="font-bold text-gray-600">{t("likes.empty")}</p>
            <p className="px-6 text-center text-xs text-gray-400">{t("likes.emptyHint")}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            {rows.map((row) => {
              const age = ageFromBirthday(row.profile.birthday);
              return (
                <div key={row.likeId} className="card flex items-center gap-3 p-3">
                  <Link href={`/discover/${row.otherUserId}`} className="flex min-w-0 flex-1 items-center gap-3">
                    <div className="h-14 w-14 shrink-0 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
                      {row.photoUrl && (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={row.photoUrl} alt="" className="h-full w-full object-cover" />
                      )}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-bold text-[var(--brand-navy)]">{row.profile.name}</p>
                      <p className="truncate text-xs text-[var(--ink-muted)]">
                        {age ? `${age}歳` : ""} {row.profile.major ? `・ ${row.profile.major}` : ""}
                      </p>
                    </div>
                  </Link>
                  <button
                    onClick={() => handleThanks(row)}
                    disabled={thankedIds.has(row.likeId)}
                    className="btn-primary shrink-0 px-4 py-2 text-xs disabled:opacity-50"
                  >
                    {thankedIds.has(row.likeId) ? t("likes.thanksSent") : t("likes.thanks")}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </main>
      <NavBar />
    </div>
  );
}
