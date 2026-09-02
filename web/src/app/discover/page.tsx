"use client";

import { startTransition, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { NavBar } from "@/components/NavBar";
import { PageHeader } from "@/components/PageHeader";
import { TutorialSpotlight, TutorialClosingCard } from "@/components/TutorialSpotlight";
import { useTutorialAnchors } from "@/lib/useTutorialAnchors";
import { isEligibleForOnboardingTutorial, hasSeenTutorial, markSeenTutorial } from "@/lib/tutorialState";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { createClient } from "@/lib/supabase/client";
import { applyCandidateFilters, loadMainPhotoUrls } from "@/lib/discover";
import {
  genderOptions,
  majorOptions,
  nationalities as nationalityOptions,
  personalityOptions,
  UNSELECTED_OPTION,
} from "@/lib/constants";
import {
  ageFromBirthday,
  defaultDiscoverFilter,
  isDiscoverFilterActive,
  type DiscoverFilter,
  type Like,
  type Match,
  type Profile,
} from "@/lib/types";

interface Candidate extends Profile {
  photoUrl?: string;
  likedMe?: boolean;
}

interface Celebration {
  profile: Profile;
  photoUrl?: string;
  matchId: string;
}

const PAGE_SIZE = 20;

export default function DiscoverPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { t } = useTranslation();

  const [userId, setUserId] = useState<string | null>(null);
  const [myProfile, setMyProfile] = useState<Profile | null>(null);
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [likedIds, setLikedIds] = useState<Set<string>>(new Set());
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [currentPage, setCurrentPage] = useState(0);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [celebration, setCelebration] = useState<Celebration | null>(null);

  const [filter, setFilter] = useState<DiscoverFilter>(defaultDiscoverFilter);
  const [showFilterSheet, setShowFilterSheet] = useState(false);
  const [draftFilter, setDraftFilter] = useState<DiscoverFilter>(defaultDiscoverFilter);

  // iOS版 DiscoverTutorialOverlay と同じ、サインアップ直後だけの簡易チュートリアル。
  // Web版には「今日のミッション」バナーがまだ無いため、絞り込み→ダミー候補の
  // いいね体験→マイページ案内、の順に簡略化している。
  type TutorialStep = "filter" | "candidate" | "myPageGuide" | "closing" | null;
  const [tutorialStep, setTutorialStep] = useState<TutorialStep>(null);
  const { rects: tutorialRects, ref: tutorialRef } = useTutorialAnchors();
  const [showingFakeProfile, setShowingFakeProfile] = useState(false);
  const [simulatedLiked, setSimulatedLiked] = useState(false);
  const sampleAvatarURL =
    "https://api.dicebear.com/9.x/adventurer/png?seed=tutorial-sample&size=400&backgroundColor=ffd5dc,ffdfbf,c0aede,d1d4f9,b6e3f4";

  useEffect(() => {
    if (isEligibleForOnboardingTutorial() && !hasSeenTutorial("Discover")) {
      const timer = setTimeout(() => setTutorialStep("filter"), 500);
      return () => clearTimeout(timer);
    }
  }, []);

  function finishTutorial() {
    setTutorialStep(null);
    markSeenTutorial("Discover");
  }

  const load = useCallback(
    async (activeFilter: DiscoverFilter, page = 0) => {
      const append = page > 0;
      if (append) setIsLoadingMore(true);
      else setIsLoading(true);
      setErrorMessage(null);

      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }
      setUserId(user.id);

      const { data: profileRow } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", user.id)
        .single();
      if (!profileRow || !profileRow.gender) {
        setErrorMessage(t("discover.profileIncomplete"));
        setIsLoading(false);
        setIsLoadingMore(false);
        return;
      }
      setMyProfile(profileRow as Profile);

      const { data: likeRows } = await supabase
        .from("likes")
        .select("*")
        .or(`from_user_id.eq.${user.id},to_user_id.eq.${user.id}`);
      const likes = (likeRows ?? []) as Like[];
      const myLikedIds = new Set(
        likes.filter((l) => l.from_user_id === user.id).map((l) => l.to_user_id)
      );
      setLikedIds(myLikedIds);

      const { data: matchRows } = await supabase
        .from("matches")
        .select("*")
        .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`);
      const matches = (matchRows ?? []) as Match[];
      const matchedPartnerIds = new Set(
        matches.map((m) => (m.user_a_id === user.id ? m.user_b_id : m.user_a_id))
      );

      // 自分が既にいいねを送った相手・マッチ済みの相手は候補に出さない。
      // (自分に届いたいいねの相手は、いいねタブ廃止後の相互いいね即マッチを機能させるため
      // あえて除外しない。カードにバッジを出して見つけやすくする。)
      const excludedIds = new Set<string>(matchedPartnerIds);
      myLikedIds.forEach((id) => excludedIds.add(id));
      const receivedLikeIds = new Set<string>();
      for (const like of likes) {
        if (like.to_user_id === user.id) receivedLikeIds.add(like.from_user_id);
      }

      const { data: hiddenRows } = await supabase
        .from("user_actions")
        .select("target_id")
        .eq("actor_id", user.id);
      for (const row of hiddenRows ?? []) excludedIds.add(row.target_id as string);

      let query = supabase.from("profiles").select("*").order("last_active_at", { ascending: false });
      query = applyCandidateFilters(query, {
        myGender: profileRow.gender,
        myUniversityId: profileRow.university_id,
        myId: user.id,
        excludedIds,
        filter: activeFilter,
      });
      query = query.range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1);

      const { data: candidateRows, error } = await query;
      if (error) {
        setErrorMessage(t("discover.loadError"));
        setIsLoading(false);
        setIsLoadingMore(false);
        return;
      }
      const rows = (candidateRows ?? []) as Profile[];
      setHasMore(rows.length === PAGE_SIZE);
      setCurrentPage(page);
      const photoUrls = await loadMainPhotoUrls(supabase, rows.map((r) => r.id));
      const mapped = rows.map((r) => ({ ...r, photoUrl: photoUrls[r.id], likedMe: receivedLikeIds.has(r.id) }));
      setCandidates((prev) => (append ? [...prev, ...mapped] : mapped));
      setIsLoading(false);
      setIsLoadingMore(false);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [router, supabase]
  );

  useEffect(() => {
    startTransition(() => {
      load(filter, 0);
    });
  }, [load, filter]);

  function loadMore() {
    if (isLoadingMore || !hasMore) return;
    load(filter, currentPage + 1);
  }

  // MatchManagerと同じ: matchesテーブルへのINSERTをRealtimeで購読し、
  // 相手からのいいねによって成立したマッチもその場で演出できるようにする。
  useEffect(() => {
    if (!userId) return;
    const channel = supabase
      .channel(`matches:${userId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "matches" },
        async (payload) => {
          const match = payload.new as Match;
          if (match.user_a_id !== userId && match.user_b_id !== userId) return;
          const otherId = match.user_a_id === userId ? match.user_b_id : match.user_a_id;
          const { data: otherProfile } = await supabase
            .from("profiles")
            .select("*")
            .eq("id", otherId)
            .single();
          if (!otherProfile) return;
          const photoUrls = await loadMainPhotoUrls(supabase, [otherId]);
          setCelebration({ profile: otherProfile as Profile, photoUrl: photoUrls[otherId], matchId: match.id });
        }
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, supabase]);

  function openFilterSheet() {
    setDraftFilter(filter);
    setShowFilterSheet(true);
  }

  function applyFilter() {
    setFilter(draftFilter);
    setShowFilterSheet(false);
    if (tutorialStep === "filter") setTutorialStep("candidate");
  }

  function closeFilterSheet() {
    setShowFilterSheet(false);
    if (tutorialStep === "filter") setTutorialStep("candidate");
  }

  return (
    <div className="app-list-background flex min-h-screen flex-col">
    <main className="mx-auto w-full max-w-4xl flex-1 px-5 py-7 sm:px-8">
      <PageHeader
        title={t("discover.title")}
        action={
          <button
            ref={tutorialRef("filter")}
            onClick={openFilterSheet}
            className={
              isDiscoverFilterActive(filter)
                ? "btn-primary px-4 py-2 text-sm"
                : "btn-secondary px-4 py-2 text-sm"
            }
          >
            <FilterIcon />
            {t("discover.filter")}
            {isDiscoverFilterActive(filter) ? " ●" : ""}
          </button>
        }
      />

      {errorMessage && (
        <p className="card mb-4 border-red-100 bg-red-50 p-3 text-sm text-red-500">{errorMessage}</p>
      )}

      {isLoading ? (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="card overflow-hidden">
              <div className="aspect-square animate-pulse bg-[#f1eff9]" />
              <div className="space-y-2 p-3">
                <div className="h-3.5 w-3/4 animate-pulse rounded bg-[#f1eff9]" />
                <div className="h-3 w-1/2 animate-pulse rounded bg-[#f1eff9]" />
              </div>
            </div>
          ))}
        </div>
      ) : candidates.length === 0 ? (
        <div className="card flex flex-col items-center gap-2 py-16 text-center">
          <p className="text-3xl">🔍</p>
          <p className="font-bold text-gray-600">{t("discover.empty")}</p>
          <p className="text-sm text-gray-400">{t("discover.emptyHint")}</p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
            {candidates.map((candidate) => (
              <CandidateCard
                key={candidate.id}
                candidate={candidate}
                alreadyLiked={likedIds.has(candidate.id)}
              />
            ))}
          </div>
          {hasMore && (
            <div className="mt-6 flex justify-center">
              <button onClick={loadMore} disabled={isLoadingMore} className="btn-secondary px-6 py-2.5 text-sm">
                {isLoadingMore ? t("discover.loadingMore") : t("discover.loadMore")}
              </button>
            </div>
          )}
        </>
      )}

      {showFilterSheet && (
        <FilterSheet
          draft={draftFilter}
          setDraft={setDraftFilter}
          onCancel={closeFilterSheet}
          onApply={applyFilter}
        />
      )}

      {celebration && (
        <MatchCelebration
          myProfile={myProfile}
          celebration={celebration}
          onClose={() => setCelebration(null)}
        />
      )}

      {tutorialStep === "filter" && !showFilterSheet && (
        <TutorialSpotlight
          rect={tutorialRects["filter"] ?? null}
          message="ここから条件(年齢・国籍・専攻など)で絞り込み検索ができます。試しに開いてみましょう。"
          onSkip={finishTutorial}
        />
      )}

      {tutorialStep === "candidate" && !showingFakeProfile && (
        <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-5 bg-black/68 px-8 text-center">
          <p className="text-sm font-bold text-white">
            最後に、気になるお相手を見つけたときの流れを体験してみましょう
          </p>
          <button onClick={() => setShowingFakeProfile(true)} className="flex flex-col items-center gap-2 rounded-2xl bg-black/25 p-3">
            <div className="h-44 w-40 overflow-hidden rounded-2xl border-2 border-white">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={sampleAvatarURL} alt="" className="h-full w-full object-cover" />
            </div>
            <p className="text-sm font-bold text-white">サンプルさん</p>
            <p className="text-xs text-white/75">20歳・体験用のサンプルです</p>
          </button>
          <p className="text-xs font-bold text-white/85">↑ タップしてプロフィールを見てみましょう</p>
          <div className="fixed top-14 right-5">
            <button onClick={finishTutorial} className="rounded-full bg-black/35 px-3.5 py-2 text-xs font-bold text-white/90">
              スキップ
            </button>
          </div>
        </div>
      )}

      {tutorialStep === "candidate" && showingFakeProfile && (
        <div className="fixed inset-0 z-[100] flex items-end justify-center bg-black/45 sm:items-center">
          <div className="max-h-[85vh] w-full max-w-sm overflow-y-auto rounded-t-3xl bg-white pb-6 sm:rounded-3xl">
            <div className="mx-auto my-3 h-1 w-10 rounded-full bg-gray-200" />
            <div className="h-56 w-full">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={sampleAvatarURL} alt="" className="h-full w-full object-cover" />
            </div>
            <div className="px-5 pt-4">
              <p className="text-lg font-bold text-[var(--brand-navy)]">サンプルさん・20歳</p>
              <p className="mt-1 text-sm text-gray-500">
                これは体験用のダミープロフィールです。実際のユーザーには、こんなふうにプロフィールが表示されます。
              </p>
            </div>
            <div className="mt-6 flex gap-3 px-5">
              <button
                disabled={simulatedLiked}
                onClick={() => {
                  setSimulatedLiked(true);
                  setTimeout(() => {
                    setShowingFakeProfile(false);
                    setSimulatedLiked(false);
                    setTutorialStep("myPageGuide");
                  }, 1100);
                }}
                className="btn-primary flex-1 py-3.5 disabled:opacity-70"
              >
                {simulatedLiked ? "送信しました!" : "👍 いいねを送る"}
              </button>
            </div>
            <p className="mt-3 px-5 text-center text-xs text-gray-400">
              {simulatedLiked
                ? "相手も自分にいいねしていたら、その場でマッチが成立します。"
                : "※ これは練習です。実際のいいねは送信されません。"}
            </p>
          </div>
        </div>
      )}

      {tutorialStep === "myPageGuide" && (
        <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-4 bg-black/75 px-8 text-center">
          <p className="text-4xl">👤</p>
          <p className="text-xl font-bold text-white">最後に「マイページ」もチェックしましょう</p>
          <p className="text-sm text-white/85">
            プロフィールの編集、いいねの購入、有料会員プランの確認、安心・安全ガイドなどはすべて画面右下の「マイページ」タブからアクセスできます
          </p>
          <button
            onClick={() => {
              finishTutorial();
              router.push("/profile");
            }}
            className="brand-gradient mt-2 w-56 rounded-full py-3.5 font-bold text-white"
          >
            マイページを見てみる
          </button>
          <button onClick={() => setTutorialStep("closing")} className="text-sm text-white/80">
            あとで見る
          </button>
        </div>
      )}

      {tutorialStep === "closing" && (
        <TutorialClosingCard
          emoji="💜"
          title="たくさんの出会いがあることを祈っています!"
          buttonLabel="はじめる"
          onFinish={finishTutorial}
        />
      )}
    </main>
    <NavBar />
    </div>
  );
}

// iOS版 Color.pastelAccent(for:) と同じ考え方: IDから決まる一貫したパステルカラー。
function pastelAccentFor(id: string): string {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = (hash * 31 + id.charCodeAt(i)) | 0;
  }
  const hue = Math.abs(hash) % 360;
  return `hsl(${hue}, 55%, 82%)`;
}

function CandidateCard({ candidate, alreadyLiked }: { candidate: Candidate; alreadyLiked: boolean }) {
  const { t, locale } = useTranslation();
  const age = ageFromBirthday(candidate.birthday);
  const accent = pastelAccentFor(candidate.id);
  return (
    <Link
      href={`/discover/${candidate.id}`}
      className="card block overflow-hidden transition hover:-translate-y-0.5"
      style={{ borderColor: accent }}
    >
      <div className="relative aspect-square bg-[#f1eff9]">
        {candidate.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={candidate.photoUrl} alt="" className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-3xl">🙂</div>
        )}
        {candidate.likedMe && (
          <span className="absolute top-2 left-2 rounded-full bg-[var(--brand-pink)] px-2 py-0.5 text-[10px] font-bold text-white shadow">
            ♥ {t("discover.likesMe")}
          </span>
        )}
        {alreadyLiked && (
          <span className="absolute right-2 bottom-2 rounded-full bg-black/55 px-2 py-0.5 text-[10px] font-bold text-white">
            {t("discover.likeSent")}
          </span>
        )}
      </div>
      <div className="p-3">
        <p className="truncate font-bold text-[var(--brand-navy)]">{candidate.name}</p>
        <p className="truncate text-xs text-gray-400">
          {age ? (locale === "ja" ? `${age}歳` : `${age}`) : ""} {candidate.major ? `・ ${candidate.major}` : ""}
        </p>
      </div>
    </Link>
  );
}

function FilterIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.3} strokeLinecap="round" strokeLinejoin="round">
      <line x1="4" y1="6" x2="20" y2="6" />
      <circle cx="9" cy="6" r="2" fill="currentColor" stroke="none" />
      <line x1="4" y1="12" x2="20" y2="12" />
      <circle cx="15" cy="12" r="2" fill="currentColor" stroke="none" />
      <line x1="4" y1="18" x2="20" y2="18" />
      <circle cx="11" cy="18" r="2" fill="currentColor" stroke="none" />
    </svg>
  );
}

function FilterSheet({
  draft,
  setDraft,
  onCancel,
  onApply,
}: {
  draft: DiscoverFilter;
  setDraft: (f: DiscoverFilter) => void;
  onCancel: () => void;
  onApply: () => void;
}) {
  const { t } = useTranslation();

  function toggle(key: "nationalities" | "personalities" | "majors" | "genders", value: string) {
    const current = draft[key];
    const next = current.includes(value)
      ? current.filter((v) => v !== value)
      : [...current, value];
    setDraft({ ...draft, [key]: next });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/45 backdrop-blur-sm sm:items-center">
      <div className="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-t-3xl bg-white p-6 shadow-2xl sm:rounded-3xl">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-gray-200 sm:hidden" />
        <div className="mb-5 flex items-center justify-between">
          <h2 className="text-lg font-bold text-[var(--brand-navy)]">{t("discover.filterTitle")}</h2>
          {isDiscoverFilterActive(draft) && (
            <button
              onClick={() => setDraft(defaultDiscoverFilter)}
              className="text-xs font-bold text-gray-400 underline hover:text-gray-600"
            >
              {t("discover.reset")}
            </button>
          )}
        </div>

        <FilterField label={`${t("discover.age")} ${draft.ageMin}+`}>
          <input
            type="range"
            min={18}
            max={40}
            value={draft.ageMin}
            onChange={(e) => setDraft({ ...draft, ageMin: Number(e.target.value) })}
            className="w-full accent-[var(--brand-purple)]"
          />
        </FilterField>

        <FilterField label={t("discover.gender")}>
          <ChipGroup
            options={genderOptions.map((g) => g.label)}
            selected={draft.genders}
            onToggle={(v) => toggle("genders", v)}
          />
        </FilterField>

        <FilterField label={t("discover.nationality")}>
          <ChipGroup
            options={nationalityOptions}
            selected={draft.nationalities}
            onToggle={(v) => toggle("nationalities", v)}
          />
        </FilterField>

        <FilterField label={t("discover.personality")}>
          <ChipGroup
            options={personalityOptions.filter((o) => o !== UNSELECTED_OPTION)}
            selected={draft.personalities}
            onToggle={(v) => toggle("personalities", v)}
          />
        </FilterField>

        <FilterField label={t("discover.major")}>
          <ChipGroup
            options={majorOptions.filter((o) => o !== UNSELECTED_OPTION)}
            selected={draft.majors}
            onToggle={(v) => toggle("majors", v)}
          />
        </FilterField>

        <div className="mt-6 flex gap-3">
          <button onClick={onCancel} className="btn-secondary flex-1 py-3">
            {t("common.cancel")}
          </button>
          <button onClick={onApply} className="btn-primary flex-1 py-3">
            {t("discover.applyFilter")}
          </button>
        </div>
      </div>
    </div>
  );
}

function FilterField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="mb-5">
      <p className="mb-2 text-sm font-bold text-gray-500">{label}</p>
      {children}
    </div>
  );
}

function ChipGroup({
  options,
  selected,
  onToggle,
}: {
  options: string[];
  selected: string[];
  onToggle: (v: string) => void;
}) {
  return (
    <div className="flex max-h-40 flex-wrap gap-2 overflow-y-auto">
      {options.map((option) => {
        const isSelected = selected.includes(option);
        return (
          <button
            key={option}
            type="button"
            onClick={() => onToggle(option)}
            className="chip"
            data-selected={isSelected}
          >
            {option}
          </button>
        );
      })}
    </div>
  );
}

function MatchCelebration({
  myProfile,
  celebration,
  onClose,
}: {
  myProfile: Profile | null;
  celebration: Celebration;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  return (
    <div className="brand-gradient fixed inset-0 z-50 flex flex-col items-center justify-center gap-5 px-6 text-center text-white">
      <p className="text-4xl">🎉</p>
      <h2 className="text-3xl font-extrabold tracking-tight">{t("discover.matched")}</h2>
      <div className="flex items-center">
        <Avatar url={myProfile?.profile_image_url} className="z-10 -mr-4" />
        <Avatar url={celebration.photoUrl} />
      </div>
      <p className="text-lg font-bold">
        {celebration.profile.name}
        {t("discover.matchedWith")}
      </p>
      <p className="text-sm opacity-90">{t("discover.startChat")}</p>
      <Link
        href={`/chat/${celebration.matchId}`}
        className="mt-2 rounded-full bg-white px-10 py-3.5 font-bold text-[var(--brand-purple-dark)] shadow-xl"
      >
        {t("discover.startChatButton")}
      </Link>
      <button onClick={onClose} className="text-sm font-semibold text-white/80 underline">
        {t("common.close")}
      </button>
    </div>
  );
}

function Avatar({ url, className = "" }: { url?: string | null; className?: string }) {
  return (
    <div className={`h-24 w-24 overflow-hidden rounded-full border-4 border-white bg-white/30 shadow-lg ${className}`}>
      {url && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt="" className="h-full w-full object-cover" />
      )}
    </div>
  );
}
