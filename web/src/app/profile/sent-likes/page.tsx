"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { ageFromBirthday, type Match, type Profile } from "@/lib/types";

interface SentLikeRow {
  toUserId: string;
  createdAt: string;
  profile: Profile;
  photoUrl?: string;
  isMatched: boolean;
}

export default function SentLikesPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [rows, setRows] = useState<SentLikeRow[]>([]);
  const [isLoading, setIsLoading] = useState(true);

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

      const [{ data: likeRows }, { data: matchRows }] = await Promise.all([
        supabase
          .from("likes")
          .select("to_user_id, created_at")
          .eq("from_user_id", user.id)
          .order("created_at", { ascending: false }),
        supabase.from("matches").select("*").or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`),
      ]);
      if (cancelled) return;

      const matches = (matchRows ?? []) as Match[];
      const matchedPartnerIds = new Set(
        matches.map((m) => (m.user_a_id === user.id ? m.user_b_id : m.user_a_id))
      );

      const toUserIds = (likeRows ?? []).map((r) => r.to_user_id as string);
      if (toUserIds.length === 0) {
        setRows([]);
        setIsLoading(false);
        return;
      }

      const [{ data: profileRows }, photoUrls] = await Promise.all([
        supabase.from("profiles").select("*").in("id", toUserIds),
        loadMainPhotoUrls(supabase, toUserIds),
      ]);
      if (cancelled) return;

      const profilesById = new Map((profileRows ?? []).map((p) => [p.id, p as Profile]));
      const result: SentLikeRow[] = (likeRows ?? [])
        .map((r): SentLikeRow | null => {
          const profile = profilesById.get(r.to_user_id as string);
          if (!profile) return null;
          return {
            toUserId: r.to_user_id as string,
            createdAt: r.created_at as string,
            profile,
            photoUrl: photoUrls[r.to_user_id as string],
            isMatched: matchedPartnerIds.has(r.to_user_id as string),
          };
        })
        .filter((r): r is SentLikeRow => r !== null);

      setRows(result);
      setIsLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [router, supabase]);

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("sentLikes.title")} />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        {rows.length === 0 ? (
          <div className="card flex flex-col items-center gap-2 py-16 text-center">
            <p className="text-3xl">💜</p>
            <p className="font-bold text-gray-600">{t("sentLikes.empty")}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            {rows.map((row) => {
              const age = ageFromBirthday(row.profile.birthday);
              return (
                <Link
                  key={row.toUserId}
                  href={`/discover/${row.toUserId}`}
                  className="card flex items-center gap-3 p-3"
                >
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
                  <span
                    className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${
                      row.isMatched
                        ? "bg-[var(--brand-teal)]/15 text-[var(--brand-teal)]"
                        : "bg-gray-100 text-gray-500"
                    }`}
                  >
                    {row.isMatched ? t("sentLikes.matched") : t("sentLikes.sentLabel")}
                  </span>
                </Link>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
