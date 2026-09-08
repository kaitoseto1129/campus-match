"use client";

import { startTransition, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { NavBar } from "@/components/NavBar";
import { PageHeader } from "@/components/PageHeader";
import { TutorialSpotlight, TutorialClosingCard } from "@/components/TutorialSpotlight";
import { useTutorialAnchors } from "@/lib/useTutorialAnchors";
import { isEligibleForOnboardingTutorial, hasSeenTutorial, markSeenTutorial } from "@/lib/tutorialState";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { loadMainPhotoUrls } from "@/lib/photos";
import { gatheringCategoryOptions } from "@/lib/constants";
import type { Gathering, GatheringApplication, Profile } from "@/lib/types";

// datetime-local inputの min 属性用に、現在時刻を "YYYY-MM-DDTHH:mm" 形式(ローカルタイム)で返す。
function minDateTimeLocal(): string {
  const now = new Date();
  now.setSeconds(0, 0);
  const offsetMs = now.getTimezoneOffset() * 60000;
  return new Date(now.getTime() - offsetMs).toISOString().slice(0, 16);
}

interface Summary {
  gathering: Gathering;
  hostProfile?: Profile;
  hostPhotoUrl?: string;
  acceptedCount: number;
  pendingCount: number;
  myApplication?: GatheringApplication;
  isHost: boolean;
}

type Segment = "browse" | "hosted";
type BrowseSubSegment = "all" | "applied";

export default function GatheringsPage() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { t } = useTranslation();

  const [segment, setSegment] = useState<Segment>("browse");
  const [browseSubSegment, setBrowseSubSegment] = useState<BrowseSubSegment>("all");
  const [summaries, setSummaries] = useState<Summary[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [showCreate, setShowCreate] = useState(false);

  // iOS版 GatheringTutorialOverlay と同じ、サインアップ直後だけの簡易チュートリアル。
  type TutorialStep = "segments" | "createButton" | "closing" | null;
  const [tutorialStep, setTutorialStep] = useState<TutorialStep>(null);
  const { rects: tutorialRects, ref: tutorialRef } = useTutorialAnchors();

  useEffect(() => {
    if (isEligibleForOnboardingTutorial() && !hasSeenTutorial("Gathering")) {
      const timer = setTimeout(() => setTutorialStep("segments"), 500);
      return () => clearTimeout(timer);
    }
  }, []);

  function finishGatheringTutorial() {
    setTutorialStep(null);
    markSeenTutorial("Gathering");
  }

  const load = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }
    const { data: profileRow } = await supabase
      .from("profiles")
      .select("university_id")
      .eq("id", user.id)
      .single();
    if (!profileRow) {
      setIsLoading(false);
      return;
    }

    const { data: gatheringRows, error } = await supabase
      .from("gatherings")
      .select("*")
      .eq("university_id", profileRow.university_id)
      .order("scheduled_at", { ascending: true });
    if (error) {
      setErrorMessage(t("gatherings.loadError"));
      setIsLoading(false);
      return;
    }
    const gatherings = (gatheringRows ?? []) as Gathering[];
    if (gatherings.length === 0) {
      setSummaries([]);
      setIsLoading(false);
      return;
    }

    const { data: applicationRows } = await supabase
      .from("gathering_applications")
      .select("*")
      .in(
        "gathering_id",
        gatherings.map((g) => g.id)
      );
    const applications = (applicationRows ?? []) as GatheringApplication[];

    const hostIds = Array.from(new Set(gatherings.map((g) => g.host_id)));
    const { data: hostRows } = await supabase.from("profiles").select("*").in("id", hostIds);
    const hostsById = new Map((hostRows ?? []).map((p) => [p.id, p as Profile]));
    const hostPhotoUrls = await loadMainPhotoUrls(supabase, hostIds);

    const applicationsByGathering = new Map<string, GatheringApplication[]>();
    for (const app of applications) {
      const list = applicationsByGathering.get(app.gathering_id) ?? [];
      list.push(app);
      applicationsByGathering.set(app.gathering_id, list);
    }

    const result: Summary[] = gatherings.map((gathering) => {
      const apps = applicationsByGathering.get(gathering.id) ?? [];
      return {
        gathering,
        hostProfile: hostsById.get(gathering.host_id),
        hostPhotoUrl: hostPhotoUrls[gathering.host_id],
        acceptedCount: apps.filter((a) => a.status === "accepted").length,
        pendingCount: apps.filter((a) => a.status === "pending").length,
        myApplication: apps.find((a) => a.applicant_id === user.id),
        isHost: gathering.host_id === user.id,
      };
    });

    setSummaries(result);
    setIsLoading(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router, supabase]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  const visible = summaries.filter((s) => {
    if (segment === "hosted") return s.isHost;
    if (s.isHost) return false;
    const isOpenAndUpcoming =
      s.gathering.status === "open" && new Date(s.gathering.scheduled_at) > new Date();
    if (!(s.myApplication !== undefined || isOpenAndUpcoming)) return false;
    if (browseSubSegment === "applied") return s.myApplication !== undefined;
    return true;
  });

  return (
    <div className="app-list-background flex min-h-screen flex-col">
    <main className="mx-auto w-full max-w-5xl flex-1 px-5 py-7 sm:px-8">
      <PageHeader
        title={t("gatherings.title")}
        action={
          <button
            ref={tutorialRef("gatheringCreate")}
            onClick={() => setShowCreate(true)}
            className="btn-primary px-4 py-2 text-sm"
          >
            {t("gatherings.create")}
          </button>
        }
      />

      <div ref={tutorialRef("gatheringSegments")} className="mb-5 flex rounded-full border border-black/5 bg-black/[0.05] p-1">
        <button
          onClick={() => setSegment("browse")}
          className={`flex-1 rounded-full py-2 text-sm font-bold transition ${
            segment === "browse" ? "bg-white text-[var(--brand-purple-dark)] shadow" : "text-gray-400"
          }`}
        >
          {t("gatherings.browse")}
        </button>
        <button
          onClick={() => setSegment("hosted")}
          className={`flex-1 rounded-full py-2 text-sm font-bold transition ${
            segment === "hosted" ? "bg-white text-[var(--brand-purple-dark)] shadow" : "text-gray-400"
          }`}
        >
          {t("gatherings.hosted")}
        </button>
      </div>

      {segment === "browse" && (
        <div className="mb-5 flex gap-2">
          <button
            onClick={() => setBrowseSubSegment("all")}
            className={`rounded-full px-4 py-1.5 text-xs font-bold transition ${
              browseSubSegment === "all"
                ? "bg-[var(--brand-purple)] text-white"
                : "bg-[#f1eff9] text-gray-400"
            }`}
          >
            {t("gatherings.browseAll")}
          </button>
          <button
            onClick={() => setBrowseSubSegment("applied")}
            className={`rounded-full px-4 py-1.5 text-xs font-bold transition ${
              browseSubSegment === "applied"
                ? "bg-[var(--brand-purple)] text-white"
                : "bg-[#f1eff9] text-gray-400"
            }`}
          >
            {t("gatherings.browseApplied")}
          </button>
        </div>
      )}

      {isLoading ? (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="card h-28 animate-pulse bg-[#f8f7fc]" />
          ))}
        </div>
      ) : errorMessage ? (
        <p className="card p-4 text-sm text-red-500">{errorMessage}</p>
      ) : visible.length === 0 ? (
        <div className="card flex flex-col items-center gap-2 py-16 text-center">
          <p className="text-3xl">🎉</p>
          <p className="font-bold text-gray-600">
            {segment === "hosted"
              ? t("gatherings.emptyHosted")
              : browseSubSegment === "applied"
                ? t("gatherings.emptyBrowseApplied")
                : t("gatherings.emptyBrowse")}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2 lg:grid-cols-3">
          {visible.map((summary) => (
            <GatheringCard key={summary.gathering.id} summary={summary} />
          ))}
        </div>
      )}

      {showCreate && (
        <CreateGatheringSheet
          onClose={() => setShowCreate(false)}
          onCreated={() => {
            setShowCreate(false);
            load();
          }}
        />
      )}

      {tutorialStep === "segments" && (
        <TutorialSpotlight
          rect={tutorialRects["gatheringSegments"] ?? null}
          message="「みんなの募集」で他の人が募集している集まりを探せます。「自分が主催」では自分が募集した・応募した集まりを確認できます。"
          onSkip={finishGatheringTutorial}
          nextLabel="次へ"
          onNext={() => setTutorialStep("createButton")}
        />
      )}
      {tutorialStep === "createButton" && (
        <TutorialSpotlight
          rect={tutorialRects["gatheringCreate"] ?? null}
          message="ここから「ご飯行きませんか」のような集まりを自分で募集できます。応募が来たら承認して、そのままグループトークができます。"
          onSkip={finishGatheringTutorial}
          nextLabel="次へ"
          onNext={() => setTutorialStep("closing")}
        />
      )}
      {tutorialStep === "closing" && (
        <TutorialClosingCard
          emoji="👥"
          title="気軽にご飯や集まりに誘ってみましょう!"
          buttonLabel="はじめる"
          onFinish={finishGatheringTutorial}
        />
      )}
    </main>
    <NavBar />
    </div>
  );
}

// 集まり1件のカード。YouTubeの一覧と同じ組み立てで、16:9のサムネイルを大きく見せ、
// その下にアバターとテキストを置く。写真は募集時の必須項目なので基本的に必ず入るが、
// 写真必須になる前に作られた集まりのためにプレースホルダーは残してある。
function GatheringCard({ summary }: { summary: Summary }) {
  const { t } = useTranslation();
  const { gathering } = summary;
  const currentMembers = summary.acceptedCount + 1;
  const scheduledDate = new Date(gathering.scheduled_at);

  // 状態はサムネイルに重ねる。YouTubeの「ライブ」バッジと同じ位置。
  let statusBadge: { text: string; className: string } | null = null;
  if (summary.isHost && gathering.status !== "canceled" && summary.pendingCount > 0) {
    statusBadge = { text: t("gatherings.pendingBadge", { n: summary.pendingCount }), className: "bg-orange-500" };
  } else if (gathering.status === "canceled") {
    statusBadge = { text: t("gatherings.canceled"), className: "bg-gray-500" };
  } else if (!summary.isHost && summary.myApplication) {
    const map: Record<string, { text: string; className: string }> = {
      pending: { text: t("gatherings.pending"), className: "bg-orange-500" },
      accepted: { text: t("gatherings.accepted"), className: "bg-teal-500" },
      declined: { text: t("gatherings.declined"), className: "bg-gray-500" },
    };
    statusBadge = map[summary.myApplication.status] ?? null;
  }

  const meta = [
    scheduledDate.toLocaleString("ja-JP", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" }),
    gathering.location,
    gathering.category,
  ].filter(Boolean).join(" ・ ");

  return (
    <Link href={`/gatherings/${gathering.id}`} className="group block">
      <div className="relative aspect-video w-full overflow-hidden rounded-xl bg-[#f1eff9]">
        {gathering.image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={gathering.image_url}
            alt=""
            className="h-full w-full object-cover transition group-hover:scale-[1.02]"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-3xl text-gray-300">🖼</div>
        )}
        {statusBadge && (
          <span className={`absolute top-2 left-2 rounded-md px-1.5 py-1 text-[11px] font-bold text-white ${statusBadge.className}`}>
            {statusBadge.text}
          </span>
        )}
        {/* 参加人数は、YouTubeで動画の長さが出る位置に置く。 */}
        <span className="absolute right-2 bottom-2 rounded-md bg-black/75 px-1.5 py-1 text-[11px] font-bold text-white">
          {t("gatherings.members", { current: currentMembers, capacity: gathering.capacity })}
        </span>
      </div>

      <div className="mt-3 flex items-start gap-3">
        <div className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-[#f1eff9]">
          {summary.hostPhotoUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={summary.hostPhotoUrl} alt="" className="h-full w-full object-cover" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <p className="line-clamp-2 text-sm font-bold text-[var(--brand-navy)]">{gathering.title}</p>
          <p className="mt-1 truncate text-xs text-gray-500">{summary.hostProfile?.name ?? "-"}</p>
          <p className="truncate text-xs text-gray-500">{meta}</p>
        </div>
      </div>
    </Link>
  );
}

function CreateGatheringSheet({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const supabase = useMemo(() => createClient(), []);
  const { t } = useTranslation();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [location, setLocation] = useState("");
  const [scheduledAt, setScheduledAt] = useState("");
  const [deadlineAt, setDeadlineAt] = useState("");
  const [capacity, setCapacity] = useState(4);
  const [category, setCategory] = useState(gatheringCategoryOptions[0]);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreviewUrl, setPhotoPreviewUrl] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  function handlePhotoSelect(file: File) {
    setPhotoFile(file);
    setPhotoPreviewUrl(URL.createObjectURL(file));
  }

  async function handleCreate() {
    if (!title || !location || !scheduledAt || !photoFile) {
      setErrorMessage(t("gatherings.requiredFields"));
      return;
    }
    if (new Date(scheduledAt) <= new Date()) {
      setErrorMessage(t("gatherings.pastDateTime"));
      return;
    }
    if (deadlineAt && new Date(deadlineAt) > new Date(scheduledAt)) {
      setErrorMessage(t("gatherings.deadlineAfterEvent"));
      return;
    }
    setIsSaving(true);
    setErrorMessage(null);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { data: profileRow } = await supabase
      .from("profiles")
      .select("university_id")
      .eq("id", user.id)
      .single();
    if (!profileRow) return;

    const { data: inserted, error } = await supabase
      .from("gatherings")
      .insert({
        host_id: user.id,
        university_id: profileRow.university_id,
        title,
        description: description || null,
        location,
        scheduled_at: new Date(scheduledAt).toISOString(),
        deadline_at: deadlineAt ? new Date(deadlineAt).toISOString() : null,
        capacity,
        category,
      })
      .select("id")
      .single();
    if (error || !inserted) {
      setErrorMessage(t("gatherings.createError"));
      setIsSaving(false);
      return;
    }

    // 写真は必須。Storageのポリシーが「既存のgatheringのidをフォルダ名に持つこと」を求めるため、
    // 先に行を作ってからアップロードするしかない。そのため、アップロードに失敗した場合は
    // 写真のない集まりが残らないよう、作った行を取り消す(iOS版 GatheringManager.create と同じ)。
    const path = `${inserted.id}/${crypto.randomUUID()}.jpg`;
    const { error: uploadError } = await supabase.storage.from("gathering_photos").upload(path, photoFile);
    if (uploadError) {
      await supabase.from("gatherings").delete().eq("id", inserted.id);
      setErrorMessage(t("gatherings.photoUploadError"));
      setIsSaving(false);
      return;
    }
    const {
      data: { publicUrl },
    } = supabase.storage.from("gathering_photos").getPublicUrl(path);
    await supabase.from("gatherings").update({ image_url: publicUrl }).eq("id", inserted.id);

    setIsSaving(false);
    onCreated();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/45 backdrop-blur-sm sm:items-center">
      <div className="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-t-3xl bg-white p-6 shadow-2xl sm:rounded-3xl">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-gray-200 sm:hidden" />
        <h2 className="mb-5 text-lg font-bold text-[var(--brand-navy)]">{t("gatherings.createTitle")}</h2>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.photoRequired")}</label>
          {photoPreviewUrl ? (
            <div className="relative aspect-video w-full overflow-hidden rounded-xl">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={photoPreviewUrl} alt="" className="h-full w-full object-cover" />
              <button
                type="button"
                onClick={() => {
                  setPhotoFile(null);
                  setPhotoPreviewUrl(null);
                }}
                aria-label={t("gatherings.removePhoto")}
                className="absolute top-2 right-2 flex h-6 w-6 items-center justify-center rounded-full bg-white text-xs font-bold text-red-500 shadow"
              >
                ×
              </button>
            </div>
          ) : (
            <label className="flex aspect-video w-full cursor-pointer items-center justify-center rounded-xl border-2 border-dashed border-[#e7e4f5] text-sm font-bold text-[var(--brand-purple)] transition hover:bg-[#f8f7fd]">
              {t("gatherings.addPhoto")}
              <input
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) handlePhotoSelect(file);
                }}
              />
            </label>
          )}
        </div>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.formTitle")}</label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className="input" />
        </div>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.description")}</label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="input"
          />
        </div>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.location")}</label>
          <input value={location} onChange={(e) => setLocation(e.target.value)} className="input" />
        </div>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.dateTime")}</label>
          <input
            type="datetime-local"
            value={scheduledAt}
            min={minDateTimeLocal()}
            onChange={(e) => setScheduledAt(e.target.value)}
            className="input"
          />
        </div>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.deadline")}</label>
          <input
            type="datetime-local"
            value={deadlineAt}
            min={minDateTimeLocal()}
            max={scheduledAt || undefined}
            onChange={(e) => setDeadlineAt(e.target.value)}
            className="input"
          />
          <p className="mt-1 px-1 text-xs text-gray-400">{t("gatherings.deadlineHint")}</p>
        </div>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.capacity")}</label>
          <input
            type="number"
            min={2}
            max={8}
            value={capacity}
            onChange={(e) => setCapacity(Math.min(8, Math.max(2, Number(e.target.value) || 2)))}
            className="input"
          />
          <p className="mt-1 px-1 text-xs text-gray-400">{t("gatherings.capacityHint")}</p>
        </div>
        <div className="mb-4">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.category")}</label>
          <select value={category} onChange={(e) => setCategory(e.target.value)} className="input">
            {gatheringCategoryOptions.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </div>
        {errorMessage && <p className="mb-3 text-sm text-red-500">{errorMessage}</p>}
        <div className="flex gap-3">
          <button onClick={onClose} className="btn-secondary flex-1 py-3">
            {t("common.cancel")}
          </button>
          <button onClick={handleCreate} disabled={isSaving} className="btn-primary flex-1 py-3">
            {isSaving ? t("gatherings.creating") : t("gatherings.submitCreate")}
          </button>
        </div>
      </div>
    </div>
  );
}
