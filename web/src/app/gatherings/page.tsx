"use client";

import { startTransition, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { NavBar } from "@/components/NavBar";
import { PageHeader } from "@/components/PageHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { loadMainPhotoUrls } from "@/lib/discover";
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
    <main className="mx-auto w-full max-w-2xl flex-1 px-5 py-7 sm:px-8">
      <PageHeader
        title={t("gatherings.title")}
        action={
          <button onClick={() => setShowCreate(true)} className="btn-primary px-4 py-2 text-sm">
            {t("gatherings.create")}
          </button>
        }
      />

      <div className="mb-5 flex rounded-full bg-[var(--paper-sunken)] p-1">
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
                : "bg-[var(--paper-sunken)] text-gray-400"
            }`}
          >
            {t("gatherings.browseAll")}
          </button>
          <button
            onClick={() => setBrowseSubSegment("applied")}
            className={`rounded-full px-4 py-1.5 text-xs font-bold transition ${
              browseSubSegment === "applied"
                ? "bg-[var(--brand-purple)] text-white"
                : "bg-[var(--paper-sunken)] text-gray-400"
            }`}
          >
            {t("gatherings.browseApplied")}
          </button>
        </div>
      )}

      {isLoading ? (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="card h-28 animate-pulse bg-[var(--paper-sunken)]" />
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
        <div className="flex flex-col gap-3">
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
    </main>
    <NavBar />
    </div>
  );
}

function GatheringCard({ summary }: { summary: Summary }) {
  const { t } = useTranslation();
  const { gathering } = summary;
  const currentMembers = summary.acceptedCount + 1;
  const scheduledDate = new Date(gathering.scheduled_at);

  let statusBadge: { text: string; className: string } | null = null;
  if (summary.isHost && gathering.status !== "canceled" && summary.pendingCount > 0) {
    statusBadge = { text: t("gatherings.pendingBadge", { n: summary.pendingCount }), className: "bg-orange-500 text-white" };
  } else if (gathering.status === "canceled") {
    statusBadge = { text: t("gatherings.canceled"), className: "bg-gray-400 text-white" };
  } else if (!summary.isHost && summary.myApplication) {
    const map: Record<string, { text: string; className: string }> = {
      pending: { text: t("gatherings.pending"), className: "bg-orange-100 text-orange-600" },
      accepted: { text: t("gatherings.accepted"), className: "bg-teal-100 text-teal-600" },
      declined: { text: t("gatherings.declined"), className: "bg-gray-100 text-gray-500" },
    };
    statusBadge = map[summary.myApplication.status] ?? null;
  }

  return (
    <Link href={`/gatherings/${gathering.id}`} className="card block p-4 transition hover:-translate-y-0.5">
      {gathering.image_url && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={gathering.image_url}
          alt=""
          className="mb-3 h-32 w-full rounded-xl object-cover"
        />
      )}
      <div className="mb-1 flex items-start justify-between gap-2">
        <div>
          <p className="font-bold text-[var(--brand-navy)]">{gathering.title}</p>
          {gathering.category && (
            <span className="mt-1 inline-block rounded-full bg-[var(--brand-teal)]/15 px-2 py-0.5 text-xs font-bold text-[var(--brand-teal)]">
              {gathering.category}
            </span>
          )}
        </div>
        {statusBadge && (
          <span className={`shrink-0 rounded-full px-2 py-1 text-xs font-bold ${statusBadge.className}`}>
            {statusBadge.text}
          </span>
        )}
      </div>
      <p className="text-xs text-gray-400">
        🕒 {scheduledDate.toLocaleString("ja-JP", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" })}
        {"  "}📍 {gathering.location}
      </p>
      <div className="mt-2 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="h-6 w-6 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
            {summary.hostPhotoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={summary.hostPhotoUrl} alt="" className="h-full w-full object-cover" />
            )}
          </div>
          <p className="text-xs font-bold text-gray-600">{summary.hostProfile?.name ?? "-"}</p>
        </div>
        <p className="text-xs font-bold text-[var(--brand-purple-dark)]">
          👥 {t("gatherings.members", { current: currentMembers, capacity: gathering.capacity })}
        </p>
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
    if (!title || !location || !scheduledAt) {
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

    // 写真は任意項目。アップロードに失敗しても集まり自体の作成は失敗させない
    // (iOS版 GatheringManager.uploadImage と同じ考え方)。
    if (photoFile) {
      const path = `${inserted.id}/${crypto.randomUUID()}.jpg`;
      const { error: uploadError } = await supabase.storage.from("gathering_photos").upload(path, photoFile);
      if (!uploadError) {
        const {
          data: { publicUrl },
        } = supabase.storage.from("gathering_photos").getPublicUrl(path);
        await supabase.from("gatherings").update({ image_url: publicUrl }).eq("id", inserted.id);
      }
    }

    setIsSaving(false);
    onCreated();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/45 backdrop-blur-sm sm:items-center">
      <div className="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-t-3xl bg-white p-6 shadow-2xl sm:rounded-3xl">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-gray-200 sm:hidden" />
        <h2 className="mb-5 text-lg font-bold text-[var(--brand-navy)]">{t("gatherings.createTitle")}</h2>
        <div className="mb-3">
          <label className="mb-1 block text-sm font-bold text-gray-500">{t("gatherings.photoOptional")}</label>
          {photoPreviewUrl ? (
            <div className="relative h-32 w-full overflow-hidden rounded-xl">
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
            <label className="flex h-24 w-full cursor-pointer items-center justify-center rounded-xl border-2 border-dashed border-[var(--line)] text-sm text-[var(--brand-purple)] transition hover:bg-[var(--brand-purple-soft)]">
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
