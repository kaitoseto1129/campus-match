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
          <div className="h-[90px] w-[90px] overflow-hidden rounded-full border-4 border-white bg-[var(--paper-sunken)] shadow-md">
            {mainPhotoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={mainPhotoUrl} alt="" className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-3xl">🙂</div>
            )}
          </div>
          <Link
            href="/profile/edit"
            className="btn-primary mt-3 px-5 py-2.5 text-sm"
          >
            ✎ {t("myPage.editProfile")}
          </Link>
        </div>

        <div className="flex flex-col gap-4">
          <MyPageExtras profile={profile} userId={userId} onProfileChange={setProfile} />
          <ProfileCompletenessCard profile={profile} photoCount={photoCount} />
          <MyPageMenu />
          <MyPageSupport />
          <MyPageSettings profile={profile} onProfileChange={setProfile} />
        </div>
      </main>
      <NavBar />
    </div>
  );
}
