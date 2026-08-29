"use client";

import { use, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { ageFromBirthday, type Profile, type ProfilePhoto, type University } from "@/lib/types";

export default function CandidateDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { t, locale } = useTranslation();

  const REPORT_REASONS = [
    t("discoverDetail.reportReasons.spam"),
    t("discoverDetail.reportReasons.impersonation"),
    t("discoverDetail.reportReasons.inappropriatePhoto"),
    t("discoverDetail.reportReasons.harassment"),
    t("discoverDetail.reportReasons.underage"),
    t("discoverDetail.reportReasons.other"),
  ];

  const [profile, setProfile] = useState<Profile | null>(null);
  const [university, setUniversity] = useState<University | null>(null);
  const [photos, setPhotos] = useState<ProfilePhoto[]>([]);
  const [alreadyLiked, setAlreadyLiked] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [celebrationMatchId, setCelebrationMatchId] = useState<string | null>(null);
  const [showingMenu, setShowingMenu] = useState(false);
  const [showingReportSheet, setShowingReportSheet] = useState(false);
  const [moderationMessage, setModerationMessage] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setIsLoading(true);
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }
      const { data: profileRow } = await supabase.from("profiles").select("*").eq("id", id).single();
      if (cancelled) return;
      if (!profileRow) {
        setIsLoading(false);
        return;
      }
      setProfile(profileRow as Profile);

      const [{ data: uniRow }, { data: photoRows }, { data: likeRows }, { data: myProfileRow }] = await Promise.all([
        supabase.from("universities").select("*").eq("id", profileRow.university_id).single(),
        supabase.from("profile_photos").select("*").eq("user_id", id).order("order_number", { ascending: true }),
        supabase.from("likes").select("id").eq("from_user_id", user.id).eq("to_user_id", id),
        supabase.from("profiles").select("private_mode").eq("id", user.id).single(),
      ]);
      if (cancelled) return;
      if (uniRow) setUniversity(uniRow as University);
      setPhotos((photoRows ?? []) as ProfilePhoto[]);
      setAlreadyLiked((likeRows ?? []).length > 0);
      setIsLoading(false);

      // iOS版 OtherUserProfileView.recordVisitIfNeeded() と同じ: 足あと(profile_visits)を記録する。
      // これが無いと「気になるお相手のプロフィールを見よう」ミッションがWeb版では永久に達成できない。
      if (user.id !== id && !myProfileRow?.private_mode) {
        supabase
          .from("profile_visits")
          .insert({ viewer_id: user.id, visited_id: id })
          .then(({ error }) => {
            if (error) console.error("record profile visit error", error);
          });
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [id, router, supabase]);

  async function handleLike() {
    if (isSending || alreadyLiked) return;
    setIsSending(true);
    setErrorMessage(null);
    const { data, error } = await supabase.rpc("send_like_atomic", {
      p_to_user_id: id,
      p_is_special: false,
    });
    setIsSending(false);
    if (error) {
      setErrorMessage(t("discoverDetail.likeError"));
      return;
    }
    setAlreadyLiked(true);
    const result = Array.isArray(data) ? data[0] : data;
    if (result?.matched && result.match_id) {
      setCelebrationMatchId(result.match_id);
    }
  }

  async function recordAction(action: "hide" | "block") {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    await supabase
      .from("user_actions")
      .upsert({ actor_id: user.id, target_id: id, action }, { onConflict: "actor_id,target_id,action" });
  }

  async function handleHide() {
    setShowingMenu(false);
    if (!confirm(`${profile?.name ?? t("discoverDetail.thisPerson")}${t("discoverDetail.confirmHide")}`)) return;
    await recordAction("hide");
    router.push("/discover");
  }

  async function handleBlock() {
    setShowingMenu(false);
    if (!confirm(`${profile?.name ?? t("discoverDetail.thisPerson")}${t("discoverDetail.confirmBlock")}`)) return;
    await recordAction("block");
    router.push("/discover");
  }

  async function handleReport(reason: string) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    setShowingReportSheet(false);
    setShowingMenu(false);
    if (!user) return;
    await supabase.from("reports").insert({ reporter_id: user.id, reported_id: id, reason });
    await recordAction("hide");
    setModerationMessage(t("discoverDetail.reportSent"));
    setTimeout(() => router.push("/discover"), 1200);
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-[var(--ios-background,#fff)]">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  if (!profile) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-3 bg-white text-center">
        <p className="text-gray-400">{t("discoverDetail.notFound")}</p>
        <Link href="/discover" className="text-sm font-semibold text-[var(--brand-purple-dark)]">
          {t("discoverDetail.backToDiscover")}
        </Link>
      </main>
    );
  }

  const mainPhoto = photos.find((p) => p.order_number === 0);
  const subPhotos = photos.filter((p) => p.order_number !== 0);
  const age = ageFromBirthday(profile.birthday);
  const areaLabel = profile.area ? (profile.city ? `${profile.area} ${profile.city}` : profile.area) : "-";
  const genderLabel =
    profile.gender === "male"
      ? t("discoverDetail.male")
      : profile.gender === "female"
        ? t("discoverDetail.female")
        : profile.gender === "other"
          ? t("discoverDetail.other")
          : "-";

  return (
    <div className="min-h-screen bg-white pb-28">
      <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-[#e5e5ea] bg-white/95 px-4 py-3 backdrop-blur-md">
        <button onClick={() => router.back()} aria-label={t("common.back")} className="text-xl text-[var(--brand-purple)]">
          ‹
        </button>
        <p className="flex-1 truncate font-bold text-[var(--brand-navy)]">{profile.name}</p>
        <div className="relative">
          <button
            onClick={() => setShowingMenu((v) => !v)}
            aria-label={t("discoverDetail.moreActions")}
            className="flex h-8 w-8 items-center justify-center rounded-full text-xl text-gray-400 hover:bg-gray-100"
          >
            ⋯
          </button>
          {showingMenu && (
            <>
              <div className="fixed inset-0 z-40" onClick={() => setShowingMenu(false)} />
              <div className="absolute top-10 right-0 z-50 w-48 overflow-hidden rounded-2xl bg-white py-1 shadow-[0_8px_24px_rgba(0,0,0,0.16)]">
                <button onClick={handleHide} className="block w-full px-4 py-2.5 text-left text-sm text-gray-700 hover:bg-gray-50">
                  {t("discoverDetail.hide")}
                </button>
                <button onClick={handleBlock} className="block w-full px-4 py-2.5 text-left text-sm text-red-500 hover:bg-gray-50">
                  {t("discoverDetail.block")}
                </button>
                <button
                  onClick={() => {
                    setShowingMenu(false);
                    setShowingReportSheet(true);
                  }}
                  className="block w-full px-4 py-2.5 text-left text-sm text-red-500 hover:bg-gray-50"
                >
                  {t("discoverDetail.report")}
                </button>
              </div>
            </>
          )}
        </div>
      </header>

      {showingReportSheet && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/45 backdrop-blur-sm sm:items-center">
          <div className="max-h-[85vh] w-full max-w-sm overflow-y-auto rounded-t-3xl bg-white p-6 shadow-2xl sm:rounded-3xl">
            <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-gray-200 sm:hidden" />
            <h2 className="mb-4 text-lg font-bold text-[var(--brand-navy)]">
              {profile.name}
              {t("discoverDetail.reportTitle")}
            </h2>
            <div className="flex flex-col gap-1">
              {REPORT_REASONS.map((reason) => (
                <button
                  key={reason}
                  onClick={() => handleReport(reason)}
                  className="rounded-xl px-3 py-3 text-left text-sm text-gray-700 hover:bg-gray-50"
                >
                  {reason}
                </button>
              ))}
            </div>
            <button
              onClick={() => setShowingReportSheet(false)}
              className="btn-secondary mt-4 w-full py-3"
            >
              {t("common.cancel")}
            </button>
          </div>
        </div>
      )}

      {moderationMessage && (
        <div className="fixed top-4 left-1/2 z-50 -translate-x-1/2 rounded-full bg-black/80 px-4 py-2 text-sm text-white shadow-lg">
          {moderationMessage}
        </div>
      )}

      <div className="px-4 pt-2">
        <div className="aspect-square w-full overflow-hidden rounded-[20px] bg-[#f1f1f4]">
          {mainPhoto ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={mainPhoto.url} alt="" className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-5xl">🙂</div>
          )}
        </div>
      </div>

      {profile.tagline && (
        <div className="mx-4 mt-3 rounded-2xl bg-white px-4 py-2.5 text-sm font-bold text-[var(--brand-navy)] shadow-[0_2px_8px_rgba(0,0,0,0.08)]">
          {profile.tagline}
        </div>
      )}

      {subPhotos.length > 0 && (
        <div className="mt-4 flex gap-2.5 overflow-x-auto px-4 pb-1">
          {subPhotos.map((photo) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={photo.id}
              src={photo.url}
              alt=""
              className="h-[130px] w-[130px] shrink-0 rounded-xl object-cover"
            />
          ))}
        </div>
      )}

      <div className="mt-4 px-4">
        <div className="flex flex-wrap items-baseline gap-2">
          <span className="text-xl font-bold text-[var(--brand-navy)]">{profile.name}</span>
          {age && <span className="text-sm text-gray-400">{locale === "ja" ? `${age}歳` : age}</span>}
          <span className="text-sm text-gray-400">{areaLabel}</span>
        </div>
        {university && (
          <p className="mt-1.5 text-xs text-gray-400">🎓 {university.name}</p>
        )}
        <div className="mt-3 border-t border-[#e5e5ea]" />
      </div>

      <div className="mt-3 px-4">
        <p className="mb-1 text-lg font-bold text-[var(--brand-navy)]">{t("discoverDetail.basicInfo")}</p>
        <InfoRow label={t("discoverDetail.nickname")} value={profile.name} />
        <InfoRow label={t("discoverDetail.age")} value={age ? (locale === "ja" ? `${age}歳` : `${age}`) : "-"} />
        <InfoRow label={t("discoverDetail.major")} value={profile.major ?? "-"} />
        <InfoRow label={t("discoverDetail.area")} value={areaLabel} />
        <InfoRow label={t("discoverDetail.nationality")} value={profile.nationalities.length ? profile.nationalities.join("・") : "-"} />
        <InfoRow label={t("discoverDetail.gender")} value={genderLabel} />
        <InfoRow label={t("discoverDetail.drinking")} value={profile.drinking ?? "-"} />
        <InfoRow label={t("discoverDetail.smoking")} value={profile.smoking ?? "-"} />
        <InfoRow label={t("discoverDetail.personality")} value={profile.body_type ?? "-"} />
        <InfoRow label={t("discoverDetail.languages")} value={profile.languages.length ? profile.languages.join("・") : "-"} last />
      </div>

      {profile.hobby_cards.length > 0 && (
        <div className="mt-6 px-4">
          <p className="mb-2 text-lg font-bold text-[var(--brand-navy)]">{t("discoverDetail.hobbyCards")}</p>
          <div className="flex flex-wrap gap-2">
            {profile.hobby_cards.map((card) => (
              <span key={card} className="rounded-full bg-purple-50 px-3 py-1 text-xs text-purple-600">
                {card}
              </span>
            ))}
          </div>
        </div>
      )}

      <div className="fixed inset-x-0 bottom-0 z-30 bg-white px-4 pt-2.5 pb-4 shadow-[0_-6px_14px_rgba(0,0,0,0.16)]">
        {errorMessage && <p className="mb-2 text-center text-xs text-red-500">{errorMessage}</p>}
        <button
          onClick={handleLike}
          disabled={isSending || alreadyLiked}
          className="w-full rounded-full py-3.5 text-base font-bold text-white transition disabled:opacity-60"
          style={{ background: alreadyLiked ? "#9ca3af" : "var(--brand-purple)" }}
        >
          {alreadyLiked
            ? t("discoverDetail.likeSent")
            : isSending
              ? t("discoverDetail.likeSending")
              : t("discoverDetail.likeButton")}
        </button>
      </div>

      {celebrationMatchId && (
        <div className="brand-gradient fixed inset-0 z-50 flex flex-col items-center justify-center gap-5 px-6 text-center text-white">
          <p className="text-4xl">🎉</p>
          <h2 className="text-3xl font-extrabold tracking-tight">{t("discover.matched")}</h2>
          <p className="text-lg font-bold">
            {profile.name}
            {t("discover.matchedWith")}
          </p>
          <p className="text-sm opacity-90">{t("discover.startChat")}</p>
          <Link
            href={`/chat/${celebrationMatchId}`}
            className="mt-2 rounded-full bg-white px-10 py-3.5 font-bold text-[var(--brand-purple-dark)] shadow-xl"
          >
            {t("discover.startChatButton")}
          </Link>
          <button onClick={() => setCelebrationMatchId(null)} className="text-sm font-semibold text-white/80 underline">
            {t("common.close")}
          </button>
        </div>
      )}
    </div>
  );
}

function InfoRow({ label, value, last = false }: { label: string; value: string; last?: boolean }) {
  return (
    <div className={`flex items-center justify-between py-3.5 ${last ? "" : "border-b border-[#e5e5ea]"}`}>
      <span className="text-[15px] text-gray-500">{label}</span>
      <span className="text-[15px] font-medium text-[var(--brand-purple)]">{value}</span>
    </div>
  );
}
