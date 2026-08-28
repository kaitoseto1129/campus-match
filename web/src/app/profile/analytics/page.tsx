"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import type { ProfilePhoto } from "@/lib/types";

// iOS版 ProfileSection と同じ順序のセクション定義(ファネル分析に使う)。
// otherProfiles(「他のユーザーも見てみる」)はWeb版のプロフィール詳細画面にまだ存在しないため対象外。
const SECTION_ORDER = [
  { key: "header", labelKey: "analytics.sectionHeader" },
  { key: "tagline", labelKey: "analytics.sectionTagline" },
  { key: "subPhotos", labelKey: "analytics.sectionSubPhotos" },
  { key: "nameAgeArea", labelKey: "analytics.sectionNameAgeArea" },
  { key: "basicInfo", labelKey: "analytics.sectionBasicInfo" },
  { key: "hobbyCards", labelKey: "analytics.sectionHobbyCards" },
] as const;

interface VisitRow {
  reached_section: string | null;
  photo_ids_viewed: string[] | null;
}

export default function AnalyticsPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [isLoading, setIsLoading] = useState(true);
  const [photos, setPhotos] = useState<ProfilePhoto[]>([]);
  const [visits, setVisits] = useState<VisitRow[]>([]);
  const [totalLikesReceived, setTotalLikesReceived] = useState(0);

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
      const [{ data: photoRows }, { data: visitRows }, { data: likeRows }] = await Promise.all([
        supabase.from("profile_photos").select("*").eq("user_id", user.id).order("order_number", { ascending: true }),
        supabase.from("profile_visits").select("reached_section, photo_ids_viewed").eq("visited_id", user.id),
        supabase.from("likes").select("id").eq("to_user_id", user.id),
      ]);
      if (cancelled) return;
      setPhotos((photoRows ?? []) as ProfilePhoto[]);
      setVisits((visitRows ?? []) as VisitRow[]);
      setTotalLikesReceived((likeRows ?? []).length);
      setIsLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [router, supabase]);

  const totalVisits = visits.length;
  const trackedVisits = useMemo(() => visits.filter((v) => v.reached_section).length, [visits]);
  const likeRate = totalVisits > 0 ? Math.round((totalLikesReceived / totalVisits) * 100) : 0;

  const sectionOrderIndex = useMemo(() => {
    const map = new Map<string, number>();
    SECTION_ORDER.forEach((s, i) => map.set(s.key, i));
    return map;
  }, []);

  const funnel = useMemo(() => {
    if (trackedVisits === 0) return [];
    return SECTION_ORDER.map((section) => {
      const reachedCount = visits.filter((v) => {
        if (!v.reached_section) return false;
        const reachedIdx = sectionOrderIndex.get(v.reached_section) ?? -1;
        const thisIdx = sectionOrderIndex.get(section.key) ?? 0;
        return reachedIdx >= thisIdx;
      }).length;
      return { ...section, percentage: Math.round((reachedCount / trackedVisits) * 100) };
    });
  }, [visits, trackedVisits, sectionOrderIndex]);

  const photoStats = useMemo(() => {
    return photos.map((photo, index) => ({
      photo,
      index,
      count: visits.filter((v) => v.photo_ids_viewed?.includes(photo.id)).length,
    }));
  }, [photos, visits]);

  const maxPhotoCount = Math.max(1, ...photoStats.map((p) => p.count));

  const insights = useMemo(() => {
    const list: string[] = [];
    if (funnel.length >= 2) {
      let biggestDrop = { from: "", to: "", drop: 0 };
      for (let i = 0; i < funnel.length - 1; i++) {
        const drop = funnel[i].percentage - funnel[i + 1].percentage;
        if (drop > biggestDrop.drop) {
          biggestDrop = { from: t(funnel[i].labelKey), to: t(funnel[i + 1].labelKey), drop };
        }
      }
      if (biggestDrop.drop >= 15) {
        list.push(t("analytics.insightDropoff", { from: biggestDrop.from, to: biggestDrop.to }));
      }
      const last = funnel[funnel.length - 1];
      if (last.percentage >= 50) {
        list.push(t("analytics.insightHighCompletion"));
      }
    }
    if (photoStats.length > 0) {
      const top = photoStats.reduce((a, b) => (b.count > a.count ? b : a));
      if (top.count > 0) {
        list.push(t("analytics.insightMostViewedPhoto", { n: top.index + 1 }));
      }
    }
    if (totalLikesReceived > 0 && totalVisits === 0) {
      list.push(t("analytics.insightLikesNoVisits"));
    }
    return list;
  }, [funnel, photoStats, totalLikesReceived, totalVisits, t]);

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("analytics.title")} />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        <div className="mb-4 grid grid-cols-2 gap-3">
          <div className="card p-4 text-center">
            <p className="text-3xl font-extrabold text-[var(--brand-navy)]">{totalVisits}</p>
            <p className="mt-1 text-xs text-gray-400">{t("analytics.profileViews")}</p>
          </div>
          <div className="card p-4 text-center">
            <p className="text-3xl font-extrabold text-[var(--brand-navy)]">{totalLikesReceived}</p>
            <p className="mt-1 text-xs text-gray-400">{t("analytics.likesReceived")}</p>
          </div>
        </div>

        <div className="brand-gradient mb-4 rounded-2xl p-5 text-center text-white shadow-lg shadow-purple-200">
          <p className="text-sm font-semibold opacity-90">{t("analytics.likeRate")}</p>
          <p className="text-4xl font-extrabold">{likeRate}%</p>
        </div>

        {totalVisits === 0 && insights.length === 0 ? (
          <div className="card p-5 text-center text-sm text-gray-400">{t("analytics.noVisitsYet")}</div>
        ) : (
          <>
            {insights.length > 0 && (
              <div className="card mb-4 p-4">
                <p className="mb-3 text-sm font-bold text-gray-700">💡 {t("analytics.insightsTitle")}</p>
                <ul className="flex flex-col gap-2">
                  {insights.map((insight, i) => (
                    <li key={i} className="text-sm text-gray-600">
                      💡 {insight}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {photoStats.length > 0 && (
              <div className="card mb-4 p-4">
                <p className="mb-3 text-sm font-bold text-gray-700">{t("analytics.photoStatsTitle")}</p>
                <div className="flex flex-col gap-2.5">
                  {photoStats.map(({ photo, index, count }) => (
                    <div key={photo.id} className="flex items-center gap-3">
                      <span className="w-14 shrink-0 text-xs text-gray-400">
                        {index === 0 ? t("analytics.mainPhotoLabel") : t("analytics.nthPhotoLabel", { n: index + 1 })}
                      </span>
                      <div className="h-2.5 flex-1 overflow-hidden rounded-full bg-[#f1eff9]">
                        <div
                          className="brand-gradient h-full rounded-full"
                          style={{ width: `${(count / maxPhotoCount) * 100}%` }}
                        />
                      </div>
                      <span className="w-6 shrink-0 text-right text-xs font-bold text-gray-500">{count}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {trackedVisits > 0 && (
              <div className="card p-4">
                <p className="mb-3 text-sm font-bold text-gray-700">{t("analytics.funnelTitle")}</p>
                <div className="flex flex-col gap-2.5">
                  {funnel.map((section) => (
                    <div key={section.key}>
                      <div className="mb-1 flex items-center justify-between text-xs">
                        <span className="text-gray-500">{t(section.labelKey)}</span>
                        <span className="font-bold text-[var(--brand-purple-dark)]">{section.percentage}%</span>
                      </div>
                      <div className="h-2 overflow-hidden rounded-full bg-[#f1eff9]">
                        <div
                          className="h-full rounded-full bg-[var(--brand-purple)]"
                          style={{ width: `${section.percentage}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  );
}
