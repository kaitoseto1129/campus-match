"use client";

import { startTransition, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { hobbyCardsFor } from "@/lib/hobbyCards";
import { isBoostActive, type Profile } from "@/lib/types";

interface Mission {
  key: string;
  titleKey: string;
  reward: number;
  target: number;
  current: number;
}

// iOS版 DailyMissionsManager と同じ、日本時間基準での「今日」判定。
function tokyoTodayString(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(new Date());
}

function tokyoStartOfDayIso(): string {
  const todayStr = tokyoTodayString(); // "YYYY-MM-DD" 形式
  // 日本時間の00:00 = UTCでは前日15:00。
  return new Date(`${todayStr}T00:00:00+09:00`).toISOString();
}

export function MyPageExtras({
  profile,
  userId,
  onProfileChange,
  tutorialRef,
}: {
  profile: Profile;
  userId: string;
  onProfileChange: (profile: Profile) => void;
  tutorialRef?: (id: string) => (el: HTMLElement | null) => void;
}) {
  const { t } = useTranslation();
  const [isBoosting, setIsBoosting] = useState(false);
  const [missions, setMissions] = useState<Mission[]>([]);
  const [claimedKeys, setClaimedKeys] = useState<Set<string>>(new Set());
  const [isLoadingMissions, setIsLoadingMissions] = useState(true);
  const [claimingKey, setClaimingKey] = useState<string | null>(null);

  const loadMissions = useCallback(async () => {
    setIsLoadingMissions(true);
    const supabase = createClient();
    const startOfDay = tokyoStartOfDayIso();
    const today = tokyoTodayString();

    const loggedInToday = new Date(profile.last_active_at).toDateString() === new Date().toDateString();

    const { data: likeRows } = await supabase
      .from("likes")
      .select("id")
      .eq("from_user_id", userId)
      .gte("created_at", startOfDay);
    const likesToday = likeRows?.length ?? 0;

    const { data: visitRows } = await supabase
      .from("profile_visits")
      .select("id")
      .eq("viewer_id", userId)
      .gte("created_at", startOfDay);
    const visitsToday = visitRows?.length ?? 0;

    const { data: claimRows } = await supabase
      .from("mission_claims")
      .select("mission_key")
      .eq("user_id", userId)
      .eq("claim_date", today);
    setClaimedKeys(new Set((claimRows ?? []).map((r) => r.mission_key as string)));

    setMissions([
      { key: "login", titleKey: "myPageExtras.missionLogin", reward: 2, target: 1, current: loggedInToday ? 1 : 0 },
      {
        key: "footprint",
        titleKey: "myPageExtras.missionFootprint",
        reward: 1,
        target: 1,
        current: Math.min(visitsToday, 1),
      },
      { key: "like5", titleKey: "myPageExtras.missionLike5", reward: 1, target: 5, current: Math.min(likesToday, 5) },
      { key: "like7", titleKey: "myPageExtras.missionLike7", reward: 2, target: 7, current: Math.min(likesToday, 7) },
    ]);
    setIsLoadingMissions(false);
  }, [profile.last_active_at, userId]);

  useEffect(() => {
    startTransition(() => {
      loadMissions();
    });
  }, [loadMissions]);

  async function handleBoost() {
    setIsBoosting(true);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("activate_boost");
    setIsBoosting(false);
    if (!error && data) {
      onProfileChange({ ...profile, boost_expires_at: data as string });
    }
  }

  async function handleClaim(mission: Mission) {
    setClaimingKey(mission.key);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("claim_daily_mission", {
      mission: mission.key,
      reward: mission.reward,
    });
    setClaimingKey(null);
    if (!error) {
      setClaimedKeys((prev) => new Set(prev).add(mission.key));
      if (typeof data === "number") onProfileChange({ ...profile, remaining_likes: data });
    }
  }

  const boosted = isBoostActive(profile);
  const isPaidMember = (profile.membership_tier ?? "free") !== "free";

  return (
    <section className="flex flex-col gap-4">
      <div className="brand-gradient rounded-3xl p-6 text-center text-white shadow-lg shadow-purple-200">
        <p className="text-sm font-semibold opacity-90">{t("myPageExtras.remainingLikes")}</p>
        <p className="text-5xl font-extrabold tracking-tight">{profile.remaining_likes}</p>
        <p className="mt-2 text-xs opacity-80">{t("myPageExtras.purchaseHint")}</p>
      </div>

      <div
        className={`flex items-center justify-between rounded-full px-5 py-3 text-white shadow-md shadow-purple-200/60 ${
          isPaidMember ? "brand-gradient" : "bg-[var(--brand-navy)]"
        }`}
      >
        <div className="flex items-center gap-2 text-sm font-bold">
          <span>{isPaidMember ? "👑" : "👤"}</span>
          <span>{t("myPageExtras.membershipStatus")}</span>
          <span className="rounded-full bg-white/25 px-2.5 py-0.5 text-xs font-bold">
            {t(`membershipTier.${profile.membership_tier ?? "free"}`)}
          </span>
        </div>
      </div>

      {!isPaidMember && (
        <div className="brand-gradient rounded-2xl p-4 text-white shadow-lg shadow-purple-200">
          <div className="flex items-center gap-3.5">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white/20 text-xl">
              👑
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-bold">{t("myPageExtras.upsellTitle")}</p>
              <ul className="mt-1 space-y-0.5 text-xs text-white/90">
                <li>💬 {t("myPageExtras.upsellUnlimitedMessages")}</li>
                <li>❤️ {t("myPageExtras.upsellShowLikeCount")}</li>
                <li>🙈 {t("myPageExtras.upsellPrivateMode")}</li>
              </ul>
            </div>
          </div>
          <p className="mt-3 text-[11px] text-white/75">{t("myPageExtras.purchaseHint")}</p>
        </div>
      )}

      <div
        ref={tutorialRef?.("myPageAppeal")}
        className="card p-4"
        style={{ borderColor: "color-mix(in srgb, var(--brand-orange) 45%, transparent)" }}
      >
        <p className="mb-1 text-sm font-bold text-[var(--brand-orange)]">
          ⚡ {boosted ? t("myPageExtras.boosting") : t("myPageExtras.boost")}
        </p>
        <p className="mb-3 text-xs text-gray-400">
          {boosted
            ? t("myPageExtras.boostActiveDesc", {
                time: new Date(profile.boost_expires_at!).toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" }),
              })
            : t("myPageExtras.boostInactiveDesc")}
        </p>
        <button
          onClick={handleBoost}
          disabled={isBoosting || boosted}
          className="w-full rounded-full border-[1.5px] border-[var(--brand-orange)] py-2.5 text-sm font-bold text-[var(--brand-orange)] transition disabled:opacity-40"
        >
          {boosted ? t("myPageExtras.boosting") : isBoosting ? t("common.processing") : t("myPageExtras.boostButton")}
        </button>
      </div>

      <div className="card p-4">
        <p className="mb-3 text-sm font-bold text-gray-700">{t("myPageExtras.missionsTitle")}</p>
        {isLoadingMissions ? (
          <p className="text-xs text-gray-400">{t("common.loading")}</p>
        ) : (
          <div className="flex flex-col gap-3">
            {missions.map((mission) => {
              const isComplete = mission.current >= mission.target;
              const isClaimed = claimedKeys.has(mission.key);
              return (
                <div key={mission.key} className="flex items-center justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm text-gray-700">{t(mission.titleKey)}</p>
                    <p className="mb-1 text-xs text-gray-400">
                      {t("myPageExtras.missionReward", {
                        current: mission.current,
                        target: mission.target,
                        reward: mission.reward,
                      })}
                    </p>
                    <div className="h-1.5 w-full max-w-[140px] overflow-hidden rounded-full bg-[#f1eff9]">
                      <div
                        className={`h-full rounded-full transition-all ${isComplete ? "bg-[var(--brand-teal)]" : "brand-gradient"}`}
                        style={{ width: `${Math.min(100, (mission.current / mission.target) * 100)}%` }}
                      />
                    </div>
                  </div>
                  <button
                    onClick={() => handleClaim(mission)}
                    disabled={!isComplete || isClaimed || claimingKey === mission.key}
                    className="btn-primary shrink-0 px-3 py-1.5 text-xs"
                  >
                    {isClaimed ? t("myPageExtras.claimed") : t("myPageExtras.claim")}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div ref={tutorialRef?.("myPageHobbyCards")} className="card p-4">
        <div className="mb-2 flex items-center justify-between">
          <p className="text-sm font-bold">{t("myPageExtras.hobbyCards")}</p>
          <Link href="/profile/hobby-cards" className="text-xs font-bold text-[var(--brand-purple-dark)]">
            {profile.hobby_cards.length > 0 ? t("completeness.edit") : t("completeness.set")}
          </Link>
        </div>
        {profile.hobby_cards.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {hobbyCardsFor(profile.hobby_cards).map((card) => (
              <span key={card.id} className="rounded-full bg-purple-50 px-3 py-1 text-xs text-purple-600">
                {card.emoji} {card.title}
              </span>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
