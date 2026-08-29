"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import type { Profile } from "@/lib/types";

interface Row {
  targetId: string;
  profile: Profile;
  photoUrl?: string;
}

// iOS版 ModerationListView と同じ: action("hide" / "block")ごとに汎用的に使う。
export function ModerationList({
  action,
  title,
  emptyMessageKey,
}: {
  action: "hide" | "block";
  title: string;
  emptyMessageKey: string;
}) {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [rows, setRows] = useState<Row[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [releasingId, setReleasingId] = useState<string | null>(null);

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
      const { data: actionRows } = await supabase
        .from("user_actions")
        .select("target_id")
        .eq("actor_id", user.id)
        .eq("action", action);
      if (cancelled) return;

      const ids = (actionRows ?? []).map((r) => r.target_id as string);
      if (ids.length === 0) {
        setRows([]);
        setIsLoading(false);
        return;
      }

      const [{ data: profileRows }, photoUrls] = await Promise.all([
        supabase.from("profiles").select("*").in("id", ids),
        loadMainPhotoUrls(supabase, ids),
      ]);
      if (cancelled) return;

      const profilesById = new Map((profileRows ?? []).map((p) => [p.id, p as Profile]));
      const result: Row[] = ids
        .map((id): Row | null => {
          const profile = profilesById.get(id);
          if (!profile) return null;
          return { targetId: id, profile, photoUrl: photoUrls[id] };
        })
        .filter((r): r is Row => r !== null);
      setRows(result);
      setIsLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [action, router, supabase]);

  async function handleRelease(targetId: string) {
    if (releasingId) return;
    setReleasingId(targetId);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    await supabase
      .from("user_actions")
      .delete()
      .eq("actor_id", user.id)
      .eq("target_id", targetId)
      .eq("action", action);
    setReleasingId(null);
    setRows((prev) => prev.filter((r) => r.targetId !== targetId));
  }

  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={title} />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        {isLoading ? (
          <div className="flex justify-center py-16">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
          </div>
        ) : rows.length === 0 ? (
          <div className="card flex flex-col items-center gap-2 py-16 text-center">
            <p className="text-3xl">{action === "block" ? "🚫" : "🙈"}</p>
            <p className="font-bold text-gray-600">{t(emptyMessageKey)}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            {rows.map((row) => (
              <div key={row.targetId} className="card flex items-center gap-3 p-3">
                <div className="h-12 w-12 shrink-0 overflow-hidden rounded-full bg-[#f1eff9]">
                  {row.photoUrl && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={row.photoUrl} alt="" className="h-full w-full object-cover" />
                  )}
                </div>
                <p className="min-w-0 flex-1 truncate font-bold text-[var(--brand-navy)]">{row.profile.name}</p>
                <button
                  onClick={() => handleRelease(row.targetId)}
                  disabled={releasingId === row.targetId}
                  className="btn-secondary shrink-0 px-3 py-1.5 text-xs"
                >
                  {t("moderation.release")}
                </button>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
