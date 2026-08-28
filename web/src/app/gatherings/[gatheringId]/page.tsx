"use client";

import { startTransition, use, useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { isGatheringPastDeadline, type Gathering, type GatheringApplication, type GatheringMessage, type Profile } from "@/lib/types";

interface ApplicantRow {
  application: GatheringApplication;
  profile?: Profile;
  photoUrl?: string;
}

export default function GatheringDetailPage({
  params,
}: {
  params: Promise<{ gatheringId: string }>;
}) {
  const { gatheringId } = use(params);
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { t } = useTranslation();

  const [myId, setMyId] = useState<string | null>(null);
  const [gathering, setGathering] = useState<Gathering | null>(null);
  const [hostProfile, setHostProfile] = useState<Profile | null>(null);
  const [hostPhotoUrl, setHostPhotoUrl] = useState<string | undefined>(undefined);
  const [applicants, setApplicants] = useState<ApplicantRow[]>([]);
  const [myApplication, setMyApplication] = useState<GatheringApplication | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [comment, setComment] = useState("");
  const [isApplying, setIsApplying] = useState(false);

  const isHost = gathering?.host_id === myId;
  const isAcceptedMember = myApplication?.status === "accepted";
  const isMember = isHost || isAcceptedMember;
  const acceptedCount = applicants.filter((a) => a.application.status === "accepted").length;
  const isFull = gathering ? acceptedCount + 1 >= gathering.capacity : false;

  const load = useCallback(async () => {
    setIsLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }
    setMyId(user.id);

    const { data: gatheringRow, error } = await supabase
      .from("gatherings")
      .select("*")
      .eq("id", gatheringId)
      .single();
    if (error || !gatheringRow) {
      setErrorMessage(t("gatheringDetail.notFound"));
      setIsLoading(false);
      return;
    }
    const g = gatheringRow as Gathering;
    setGathering(g);

    const { data: hostRow } = await supabase.from("profiles").select("*").eq("id", g.host_id).single();
    if (hostRow) setHostProfile(hostRow as Profile);
    const photoUrls = await loadMainPhotoUrls(supabase, [g.host_id]);
    setHostPhotoUrl(photoUrls[g.host_id]);

    const { data: applicationRows } = await supabase
      .from("gathering_applications")
      .select("*")
      .eq("gathering_id", gatheringId)
      .order("created_at", { ascending: true });
    const applications = (applicationRows ?? []) as GatheringApplication[];
    setMyApplication(applications.find((a) => a.applicant_id === user.id) ?? null);

    const applicantIds = applications.map((a) => a.applicant_id);
    if (applicantIds.length > 0) {
      const { data: profileRows } = await supabase.from("profiles").select("*").in("id", applicantIds);
      const profilesById = new Map((profileRows ?? []).map((p) => [p.id, p as Profile]));
      const applicantPhotoUrls = await loadMainPhotoUrls(supabase, applicantIds);
      setApplicants(
        applications.map((application) => ({
          application,
          profile: profilesById.get(application.applicant_id),
          photoUrl: applicantPhotoUrls[application.applicant_id],
        }))
      );
    } else {
      setApplicants([]);
    }

    setIsLoading(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [gatheringId, router, supabase]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  async function handleApply() {
    if (!gathering) return;
    if (isGatheringPastDeadline(gathering)) {
      setErrorMessage(t("gatheringDetail.pastDeadline"));
      return;
    }
    setIsApplying(true);
    setErrorMessage(null);
    const { error } = await supabase
      .from("gathering_applications")
      .insert({ gathering_id: gatheringId, applicant_id: myId, comment: comment || null });
    setIsApplying(false);
    if (error) {
      setErrorMessage(t("gatheringDetail.applyError"));
      return;
    }
    setComment("");
    await load();
  }

  async function handleWithdraw() {
    if (!myApplication) return;
    await supabase.from("gathering_applications").delete().eq("id", myApplication.id);
    await load();
  }

  async function handleRespond(application: GatheringApplication, accept: boolean) {
    const { error } = await supabase.rpc("respond_to_gathering_application", {
      p_application_id: application.id,
      p_accept: accept,
    });
    if (error) {
      setErrorMessage(accept ? t("gatheringDetail.acceptError") : t("gatheringDetail.declineError"));
      return;
    }
    await load();
  }

  async function handleCancelGathering() {
    if (!gathering) return;
    if (!confirm(t("gatheringDetail.cancelConfirm"))) return;
    const { error } = await supabase.rpc("cancel_gathering", { p_gathering_id: gathering.id });
    if (error) {
      setErrorMessage(t("gatheringDetail.cancelError"));
      return;
    }
    await load();
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  if (!gathering) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-red-500">{errorMessage ?? t("gatheringDetail.notFound")}</p>
      </main>
    );
  }

  const scheduledDate = new Date(gathering.scheduled_at);

  return (
    <div className="app-list-background min-h-screen">
    <main className="mx-auto max-w-2xl px-5 py-7 sm:px-8">
      <Link href="/gatherings" className="mb-4 inline-block text-sm font-semibold text-[var(--brand-purple-dark)]">
        {t("gatheringDetail.backToList")}
      </Link>

      <div className="card p-5">
        <h1 className="mb-1 text-xl font-bold text-[var(--brand-navy)]">{gathering.title}</h1>
        {gathering.category && (
          <span className="mb-3 inline-block rounded-full bg-[var(--brand-teal)]/15 px-2 py-0.5 text-xs font-bold text-[var(--brand-teal)]">
            {gathering.category}
          </span>
        )}

        <div className="mb-3 flex items-center gap-2">
          <div className="h-8 w-8 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
            {hostPhotoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={hostPhotoUrl} alt="" className="h-full w-full object-cover" />
            )}
          </div>
          <div>
            <p className="text-sm font-bold text-gray-700">{hostProfile?.name ?? "-"}</p>
            <p className="text-xs text-gray-400">{t("gatheringDetail.host")}</p>
          </div>
        </div>

        {gathering.description && <p className="mb-4 whitespace-pre-wrap text-sm text-gray-600">{gathering.description}</p>}

        <div className="flex flex-col gap-1.5 text-sm text-gray-500">
          <p>
            🕒{" "}
            {scheduledDate.toLocaleString("ja-JP", {
              year: "numeric",
              month: "numeric",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          </p>
          {gathering.duration_hours && <p>⏳ {t("gatheringDetail.duration", { n: gathering.duration_hours })}</p>}
          <p>📍 {gathering.location}</p>
          <div>
            <p className="mb-1 font-bold text-[var(--brand-purple-dark)]">
              {t("gatheringDetail.membersCount", { current: acceptedCount + 1, capacity: gathering.capacity })}
              {isFull && ` ・ ${t("gatheringDetail.full")}`}
            </p>
            <div className="h-1.5 w-full max-w-[160px] overflow-hidden rounded-full bg-[var(--paper-sunken)]">
              <div
                className={`h-full rounded-full transition-all ${isFull ? "bg-[var(--brand-orange)]" : "bg-[var(--brand-purple)]"}`}
                style={{ width: `${Math.min(100, ((acceptedCount + 1) / gathering.capacity) * 100)}%` }}
              />
            </div>
          </div>
          {gathering.deadline_at && (
            <p>
              {t("gatheringDetail.deadlineLabel")} {new Date(gathering.deadline_at).toLocaleString("ja-JP")}
            </p>
          )}
          {gathering.status === "canceled" && <p className="font-bold text-red-500">{t("gatheringDetail.canceled")}</p>}
        </div>
      </div>

      {errorMessage && <p className="card mt-3 border-red-100 bg-red-50 p-3 text-sm text-red-500">{errorMessage}</p>}

      {!isHost && gathering.status === "open" && !myApplication && isFull && (
        <p className="mt-4 rounded-2xl bg-gray-100 p-4 text-center text-sm font-bold text-gray-500">
          {t("gatheringDetail.fullNotAccepting")}
        </p>
      )}

      {!isHost && gathering.status === "open" && !myApplication && !isFull && (
        <div className="card mt-4 p-4">
          <textarea
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder={t("gatheringDetail.commentPlaceholder")}
            rows={2}
            className="input mb-3"
          />
          <button onClick={handleApply} disabled={isApplying} className="btn-primary w-full py-3">
            {isApplying ? t("gatheringDetail.applying") : t("gatheringDetail.apply")}
          </button>
        </div>
      )}

      {!isHost && myApplication?.status === "pending" && (
        <div className="mt-4 flex items-center justify-between rounded-2xl bg-orange-50 p-4">
          <p className="text-sm font-bold text-orange-600">{t("gatheringDetail.pendingApproval")}</p>
          <button onClick={handleWithdraw} className="text-sm text-gray-500 underline">
            {t("gatheringDetail.withdraw")}
          </button>
        </div>
      )}

      {!isHost && myApplication?.status === "declined" && (
        <p className="mt-4 rounded-2xl bg-gray-100 p-4 text-sm text-gray-500">{t("gatheringDetail.declinedNotice")}</p>
      )}

      {isHost && gathering.status !== "canceled" && (
        <div className="mt-4">
          <h2 className="mb-2 font-bold text-[var(--brand-navy)]">{t("gatheringDetail.applicantsTitle")}</h2>
          {applicants.length === 0 ? (
            <p className="text-sm text-gray-400">{t("gatheringDetail.noApplicants")}</p>
          ) : (
            <div className="flex flex-col gap-2">
              {applicants.map((row) => (
                <div key={row.application.id} className="card flex items-center gap-3 p-3">
                  <div className="h-10 w-10 shrink-0 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
                    {row.photoUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={row.photoUrl} alt="" className="h-full w-full object-cover" />
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-gray-700">{row.profile?.name ?? "-"}</p>
                    {row.application.comment && (
                      <p className="truncate text-xs text-gray-400">{row.application.comment}</p>
                    )}
                  </div>
                  {row.application.status === "pending" ? (
                    <div className="flex shrink-0 gap-2">
                      <button
                        onClick={() => handleRespond(row.application, true)}
                        disabled={isFull}
                        title={isFull ? t("gatheringDetail.fullTooltip") : undefined}
                        className="btn-primary px-3 py-1.5 text-xs disabled:opacity-40"
                      >
                        {t("gatheringDetail.acceptButton")}
                      </button>
                      <button onClick={() => handleRespond(row.application, false)} className="btn-secondary px-3 py-1.5 text-xs">
                        {t("gatheringDetail.declineButton")}
                      </button>
                    </div>
                  ) : (
                    <span
                      className={`shrink-0 rounded-full px-2 py-1 text-xs font-bold ${
                        row.application.status === "accepted"
                          ? "bg-[var(--brand-teal)]/15 text-[var(--brand-teal)]"
                          : "bg-gray-100 text-gray-500"
                      }`}
                    >
                      {row.application.status === "accepted" ? t("gatheringDetail.confirmed") : t("gatheringDetail.declinedStatus")}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}
          <button onClick={handleCancelGathering} className="mt-4 text-sm text-red-500 underline">
            {t("gatheringDetail.cancelGathering")}
          </button>
        </div>
      )}

      {isMember && gathering.status !== "canceled" && (
        <GroupChat gatheringId={gatheringId} myId={myId} />
      )}
    </main>
    </div>
  );
}

function GroupChat({ gatheringId, myId }: { gatheringId: string; myId: string | null }) {
  const supabase = useMemo(() => createClient(), []);
  const { t } = useTranslation();
  const [messages, setMessages] = useState<GatheringMessage[]>([]);
  const [senderNames, setSenderNames] = useState<Record<string, string>>({});
  const [draft, setDraft] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);

  const load = useCallback(async () => {
    const { data } = await supabase
      .from("gathering_messages")
      .select("*")
      .eq("gathering_id", gatheringId)
      .order("created_at", { ascending: true });
    const rows = (data ?? []) as GatheringMessage[];
    setMessages(rows);
    const senderIds = Array.from(new Set(rows.map((m) => m.sender_id)));
    if (senderIds.length > 0) {
      const { data: profileRows } = await supabase.from("profiles").select("id, name").in("id", senderIds);
      const names: Record<string, string> = {};
      for (const p of profileRows ?? []) names[p.id] = p.name;
      setSenderNames(names);
    }
  }, [gatheringId, supabase]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  useEffect(() => {
    const channel = supabase
      .channel(`gathering_messages:${gatheringId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "gathering_messages", filter: `gathering_id=eq.${gatheringId}` },
        (payload) => {
          const message = payload.new as GatheringMessage;
          setMessages((prev) => (prev.some((m) => m.id === message.id) ? prev : [...prev, message]));
        }
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [gatheringId, supabase]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function handleSend() {
    const trimmed = draft.trim();
    if (!trimmed || !myId) return;
    setDraft("");
    await supabase.from("gathering_messages").insert({ gathering_id: gatheringId, sender_id: myId, body: trimmed });
  }

  return (
    <div className="mt-6">
      <h2 className="mb-2 font-bold text-[var(--brand-navy)]">{t("gatheringDetail.groupChatTitle")}</h2>
      <div className="app-list-background flex h-64 flex-col overflow-y-auto rounded-2xl border border-[var(--paper-sunken)] p-3">
        {messages.map((message) => (
          <div key={message.id} className={`mb-2 flex flex-col ${message.sender_id === myId ? "items-end" : "items-start"}`}>
            {message.sender_id !== myId && (
              <p className="mb-0.5 text-xs text-gray-400">{senderNames[message.sender_id] ?? "-"}</p>
            )}
            <p
              className={`max-w-[75%] rounded-xl px-3 py-1.5 text-sm ${
                message.sender_id === myId ? "bg-[var(--brand-purple)] text-white" : "bg-white text-[var(--brand-navy)] border border-[var(--line)]"
              }`}
            >
              {message.body}
            </p>
            <p className="mt-0.5 text-[10px] text-gray-400">
              {new Date(message.created_at).toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" })}
            </p>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
      <div className="mt-2 flex gap-2">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") handleSend();
          }}
          placeholder={t("gatheringDetail.messagePlaceholder")}
          className="input flex-1"
        />
        <button onClick={handleSend} className="btn-primary px-4 text-sm">
          {t("common.send")}
        </button>
      </div>
    </div>
  );
}
