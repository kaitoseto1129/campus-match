"use client";

import { startTransition, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { NavBar } from "@/components/NavBar";
import { PageHeader } from "@/components/PageHeader";
import { MyPageExtras } from "@/components/MyPageExtras";
import { MyPageMenu, MyPageSupport } from "@/components/MyPageMenu";
import { MyPageSettings } from "@/components/MyPageSettings";
import { ProfileCompletenessCard } from "@/components/ProfileCompletenessCard";
import { TutorialSpotlight, TutorialClosingCard } from "@/components/TutorialSpotlight";
import { useTutorialAnchors } from "@/lib/useTutorialAnchors";
import { isEligibleForOnboardingTutorial, hasSeenTutorial, markSeenTutorial } from "@/lib/tutorialState";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import type { Profile } from "@/lib/types";

export default function MyPageHome() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [userId, setUserId] = useState<string | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [mainPhotoUrl, setMainPhotoUrl] = useState<string | undefined>(undefined);
  const [photoCount, setPhotoCount] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  // iOS版 MyPageTutorialOverlay と同じ、サインアップ直後だけの簡易ガイド。
  type TutorialStep = "hobbyCards" | "completeness" | "appeal" | "analytics" | "footprints" | "closing" | null;
  const [tutorialStep, setTutorialStep] = useState<TutorialStep>(null);
  const { rects: tutorialRects, ref: tutorialRef } = useTutorialAnchors();
  const tutorialOrder: TutorialStep[] = ["hobbyCards", "completeness", "appeal", "analytics", "footprints", "closing"];

  useEffect(() => {
    if (isEligibleForOnboardingTutorial() && !hasSeenTutorial("MyPage")) {
      const timer = setTimeout(() => setTutorialStep("hobbyCards"), 500);
      return () => clearTimeout(timer);
    }
  }, []);

  function advanceTutorial() {
    const idx = tutorialOrder.indexOf(tutorialStep);
    setTutorialStep(tutorialOrder[idx + 1] ?? null);
  }

  function finishTutorial() {
    setTutorialStep(null);
    markSeenTutorial("MyPage");
  }

  const tutorialAnchorId: Record<Exclude<TutorialStep, "closing" | null>, string> = {
    hobbyCards: "myPageHobbyCards",
    completeness: "myPageCompleteness",
    appeal: "myPageAppeal",
    analytics: "myPageAnalytics",
    footprints: "myPageFootprints",
  };
  const tutorialMessage: Record<Exclude<TutorialStep, "closing" | null>, string> = {
    hobbyCards: "「趣味カードを追加する」をタップして、趣味カードを登録してみましょう。共通の趣味があるお相手に見つけてもらいやすくなります",
    completeness: "足りない項目は「やることリスト」でひと目で分かります。「編集する」から埋めてみましょう",
    appeal: "「アピールを使う」をタップすると、いいねを消費して1時間だけ「探す」画面のトップに表示されます",
    analytics: "「分析」をタップすると、プロフィールの閲覧数やいいね獲得率を確認できます",
    footprints: "「足あと」をタップすると、あなたのプロフィールを見に来たお相手が分かります",
  };

  const load = useCallback(async () => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }
    setUserId(user.id);

    const [{ data: profileRow }, { data: photoRows }] = await Promise.all([
      supabase.from("profiles").select("*").eq("id", user.id).single(),
      supabase.from("profile_photos").select("url, order_number").eq("user_id", user.id).order("order_number", { ascending: true }),
    ]);
    if (profileRow) setProfile(profileRow as Profile);
    setPhotoCount(photoRows?.length ?? 0);
    setMainPhotoUrl(photoRows?.[0]?.url);
    setIsLoading(false);
  }, [router, supabase]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  if (!profile || !userId) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-gray-400">{t("profile.loadError")}</p>
      </main>
    );
  }

  return (
    <div className="app-list-background flex min-h-screen flex-col">
      <main className="mx-auto w-full max-w-lg flex-1 px-5 py-7 sm:px-8">
        <PageHeader title={t("myPage.title")} />

        <div className="mb-5 flex flex-col items-center">
          <div className="h-[90px] w-[90px] overflow-hidden rounded-full border-4 border-white bg-[#f1eff9] shadow-md">
            {mainPhotoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={mainPhotoUrl} alt="" className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-3xl">🙂</div>
            )}
          </div>
          <Link
            href="/profile/edit"
            className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-[var(--brand-purple)] px-5 py-2.5 text-sm font-bold text-white shadow-md shadow-purple-200/60"
          >
            ✎ {t("myPage.editProfile")}
          </Link>
        </div>

        <div className="flex flex-col gap-4">
          <MyPageExtras profile={profile} userId={userId} onProfileChange={setProfile} tutorialRef={tutorialRef} />
          <div ref={tutorialRef("myPageCompleteness")}>
            <ProfileCompletenessCard profile={profile} photoCount={photoCount} />
          </div>
          <MyPageMenu tutorialRef={tutorialRef} />
          <MyPageSupport />
          <MyPageSettings profile={profile} onProfileChange={setProfile} />
        </div>
      </main>
      <NavBar />

      {tutorialStep && tutorialStep !== "closing" && (
        <TutorialSpotlight
          rect={tutorialRects[tutorialAnchorId[tutorialStep]] ?? null}
          message={tutorialMessage[tutorialStep]}
          onSkip={finishTutorial}
          nextLabel="次へ"
          onNext={advanceTutorial}
        />
      )}
      {tutorialStep === "closing" && (
        <TutorialClosingCard
          emoji="💜"
          title="マイページの紹介はこれで終わりです"
          description="たくさんの出会いがあることを祈っています!"
          buttonLabel="はじめる"
          onFinish={finishTutorial}
        />
      )}
    </div>
  );
}
