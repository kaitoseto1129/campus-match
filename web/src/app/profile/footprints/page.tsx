"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { ageFromBirthday, type Profile } from "@/lib/types";

interface FootprintRow {
  viewerId: string;
  profile: Profile;
  photoUrl?: string;
  alreadyLiked: boolean;
}

export default function FootprintsPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [rows, setRows] = useState<FootprintRow[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [sendingId, setSendingId] = useState<string | null>(null);

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

      const [{ data: visitRows }, { data: likeRows }, { data: hiddenRows }] = await Promise.all([
        supabase
          .from("profile_visits")
          .select("viewer_id, created_at")
          .eq("visited_id", user.id)
          .order("created_at", { ascending: false }),
        supabase.from("likes").select("to_user_id").eq("from_user_id", user.id),
        supabase.from("user_actions").select("target_id").eq("actor_id", user.id),
      ]);
      if (cancelled) return;

      const likedIds = new Set((likeRows ?? []).map((r) => r.to_user_id as string));
      const excludedIds = new Set((hiddenRows ?? []).map((r) => r.target_id as string));

      // 同じ相手からの複数回の訪問は、最新の1件だけを残す(iOS版 FootprintsManager と同じ)。
      const latestByViewer = new Map<string, string>();
      for (const visit of visitRows ?? []) {
        const viewerId = visit.viewer_id as string;
        if (!latestByViewer.has(viewerId) && !excludedIds.has(viewerId)) {
          latestByViewer.set(viewerId, viewerId);
        }
      }
      const viewerIds = Array.from(latestByViewer.keys());
      if (viewerIds.length === 0) {
        setRows([]);
        setIsLoading(false);
        return;
      }

      const [{ data: profileRows }, photoUrls] = await Promise.all([
        supabase.from("profiles").select("*").in("id", viewerIds),
        loadMainPhotoUrls(supabase, viewerIds),
      ]);
      if (cancelled) return;

      const profilesById = new Map((profileRows ?? []).map((p) => [p.id, p as Profile]));
      const result: FootprintRow[] = viewerIds
        .map((id): FootprintRow | null => {
          const profile = profilesById.get(id);
          if (!profile) return null;
          return {
            viewerId: id,
            profile,
            photoUrl: photoUrls[id],
            alreadyLiked: likedIds.has(id),
          };
        })
        .filter((r): r is FootprintRow => r !== null);

      setRows(result);
      setIsLoading(false);

      supabase.rpc("mark_footprints_viewed");
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [router, supabase]);

  async function handleLike(row: FootprintRow) {
    if (sendingId || row.alreadyLiked) return;
    setSendingId(row.viewerId);
    const { error } = await supabase.rpc("send_like_atomic", {
      p_to_user_id: row.viewerId,
      p_is_special: false,
    });
    setSendingId(null);
    if (!error) {
      setRows((prev) => prev.map((r) => (r.viewerId === row.viewerId ? { ...r, alreadyLiked: true } : r)));
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
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("footprints.title")} />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        {rows.length === 0 ? (
          <div className="card flex flex-col items-center gap-2 py-16 text-center">
            <p className="text-3xl">👣</p>
            <p className="font-bold text-gray-600">{t("footprints.empty")}</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-4">
            {rows.map((row) => {
              const age = ageFromBirthday(row.profile.birthday);
              return (
                <div key={row.viewerId} className="card overflow-hidden">
                  <Link href={`/discover/${row.viewerId}`} className="block">
                    <div className="aspect-square bg-[var(--paper-sunken)]">
                      {row.photoUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={row.photoUrl} alt="" className="h-full w-full object-cover" />
                      ) : (
                        <div className="flex h-full w-full items-center justify-center text-3xl">🙂</div>
                      )}
                    </div>
                    <div className="p-3">
                      <p className="truncate font-bold text-[var(--brand-navy)]">{row.profile.name}</p>
                      <p className="mb-2 truncate text-xs text-[var(--ink-muted)]">
                        {age ? `${age}歳` : ""} {row.profile.major ? `・ ${row.profile.major}` : ""}
                      </p>
                    </div>
                  </Link>
                  <button
                    onClick={() => handleLike(row)}
                    disabled={sendingId === row.viewerId || row.alreadyLiked}
                    className={`mx-3 mb-3 rounded-full py-2 text-xs font-bold transition ${
                      row.alreadyLiked
                        ? "bg-gray-100 text-[var(--ink-muted)]"
                        : "btn-primary"
                    } ${sendingId === row.viewerId ? "opacity-60" : ""}`}
                    style={{ width: "calc(100% - 1.5rem)" }}
                  >
                    {row.alreadyLiked ? t("footprints.likeSent") : t("footprints.like")}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
