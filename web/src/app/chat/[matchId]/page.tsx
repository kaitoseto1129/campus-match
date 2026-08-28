"use client";

import { startTransition, use, useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { loadMainPhotoUrls } from "@/lib/discover";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import type { Match, Message, Profile } from "@/lib/types";

export default function ChatDetailPage({
  params,
}: {
  params: Promise<{ matchId: string }>;
}) {
  const { matchId } = use(params);
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { t } = useTranslation();

  const [myId, setMyId] = useState<string | null>(null);
  const [otherProfile, setOtherProfile] = useState<Profile | null>(null);
  const [otherPhotoUrl, setOtherPhotoUrl] = useState<string | undefined>(undefined);
  const [messages, setMessages] = useState<Message[]>([]);
  const [draftText, setDraftText] = useState("");
  const [isSending, setIsSending] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const bottomRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const markRead = useCallback(
    async (uid: string) => {
      await supabase
        .from("messages")
        .update({ read_at: new Date().toISOString() })
        .eq("match_id", matchId)
        .neq("sender_id", uid)
        .is("read_at", null);
    },
    [matchId, supabase]
  );

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

    const { data: matchRow } = await supabase.from("matches").select("*").eq("id", matchId).single();
    if (!matchRow) {
      setErrorMessage(t("chatDetail.notFound"));
      setIsLoading(false);
      return;
    }
    const match = matchRow as Match;
    const otherId = match.user_a_id === user.id ? match.user_b_id : match.user_a_id;

    const { data: profileRow } = await supabase.from("profiles").select("*").eq("id", otherId).single();
    if (profileRow) setOtherProfile(profileRow as Profile);
    const photoUrls = await loadMainPhotoUrls(supabase, [otherId]);
    setOtherPhotoUrl(photoUrls[otherId]);

    const { data: messageRows } = await supabase
      .from("messages")
      .select("*")
      .eq("match_id", matchId)
      .order("created_at", { ascending: true });
    setMessages((messageRows ?? []) as Message[]);
    setIsLoading(false);
    await markRead(user.id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [matchId, router, supabase, markRead]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  useEffect(() => {
    if (!myId) return;
    const channel = supabase
      .channel(`messages:${matchId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "messages", filter: `match_id=eq.${matchId}` },
        (payload) => {
          const message = payload.new as Message;
          setMessages((prev) => (prev.some((m) => m.id === message.id) ? prev : [...prev, message]));
          if (message.sender_id !== myId) markRead(myId);
        }
      )
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "messages", filter: `match_id=eq.${matchId}` },
        (payload) => {
          const message = payload.new as Message;
          setMessages((prev) => prev.map((m) => (m.id === message.id ? message : m)));
        }
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [matchId, myId, supabase, markRead]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  async function handleSend() {
    const trimmed = draftText.trim();
    if (!trimmed || isSending || !myId) return;
    setIsSending(true);
    setErrorMessage(null);
    setDraftText("");
    const { error } = await supabase
      .from("messages")
      .insert({ match_id: matchId, sender_id: myId, body: trimmed });
    if (error) {
      setErrorMessage(t("chatDetail.sendTextError"));
      setDraftText(trimmed);
    }
    setIsSending(false);
  }

  async function handleImageSelect(file: File) {
    if (!myId) return;
    setIsSending(true);
    setErrorMessage(null);
    const path = `${matchId}/${crypto.randomUUID()}.jpg`;
    const { error: uploadError } = await supabase.storage.from("chat_photos").upload(path, file, {
      contentType: file.type || "image/jpeg",
    });
    if (uploadError) {
      setErrorMessage(t("chatDetail.imageUploadError"));
      setIsSending(false);
      return;
    }
    const {
      data: { publicUrl },
    } = supabase.storage.from("chat_photos").getPublicUrl(path);
    const { error } = await supabase
      .from("messages")
      .insert({ match_id: matchId, sender_id: myId, image_url: publicUrl });
    if (error) {
      setErrorMessage(t("chatDetail.sendImageError"));
    }
    setIsSending(false);
  }

  async function handleUnsend(message: Message) {
    if (message.sender_id !== myId) return;
    await supabase
      .from("messages")
      .update({ deleted_at: new Date().toISOString() })
      .eq("id", message.id)
      .eq("sender_id", myId);
    setMessages((prev) =>
      prev.map((m) => (m.id === message.id ? { ...m, deleted_at: new Date().toISOString() } : m))
    );
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-white">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  return (
    <main className="mx-auto flex h-screen max-w-2xl flex-col bg-white">
      <header className="flex items-center gap-3 border-b border-[var(--paper-sunken)] px-4 py-3 shadow-sm">
        <Link href="/chat" className="text-lg text-[var(--brand-purple-dark)]">
          ←
        </Link>
        <Link
          href={otherProfile ? `/discover/${otherProfile.id}` : "#"}
          className="flex items-center gap-3 transition hover:opacity-75"
        >
          <div className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-[var(--paper-sunken)]">
            {otherPhotoUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={otherPhotoUrl} alt="" className="h-full w-full object-cover" />
            )}
          </div>
          <p className="font-bold text-[var(--brand-navy)]">{otherProfile?.name ?? "-"}</p>
        </Link>
      </header>

      <div className="app-list-background flex-1 overflow-y-auto p-4">
        {messages.length === 0 && (
          <div className="mt-10 flex flex-col items-center gap-2 text-center">
            <p className="text-3xl">🎉</p>
            <p className="text-sm font-semibold text-gray-500">{t("chatDetail.matchCelebration")}</p>
          </div>
        )}
        <div className="flex flex-col gap-3">
          {messages.map((message) => (
            <MessageBubble
              key={message.id}
              message={message}
              isMine={message.sender_id === myId}
              onUnsend={() => handleUnsend(message)}
            />
          ))}
        </div>
        <div ref={bottomRef} />
      </div>

      {errorMessage && <p className="bg-red-50 px-4 py-2 text-xs text-red-500">{errorMessage}</p>}

      <div className="flex items-center gap-2 border-t border-[var(--paper-sunken)] p-3">
        <button
          onClick={() => fileInputRef.current?.click()}
          disabled={isSending}
          className="btn-secondary shrink-0 px-3 py-2.5 text-sm disabled:opacity-50"
        >
          {isSending ? (
            <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent align-middle" />
          ) : (
            "📷"
          )}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handleImageSelect(file);
            e.target.value = "";
          }}
        />
        <input
          value={draftText}
          onChange={(e) => setDraftText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") handleSend();
          }}
          placeholder={t("chatDetail.messagePlaceholder")}
          className="input flex-1 py-2.5"
        />
        <button
          onClick={handleSend}
          disabled={isSending || !draftText.trim()}
          className="btn-primary shrink-0 px-5 py-2.5 text-sm"
        >
          {t("chatDetail.send")}
        </button>
      </div>
    </main>
  );
}

function messageTime(dateString: string): string {
  return new Date(dateString).toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" });
}

function MessageBubble({
  message,
  isMine,
  onUnsend,
}: {
  message: Message;
  isMine: boolean;
  onUnsend: () => void;
}) {
  const { t } = useTranslation();
  if (message.deleted_at) {
    return (
      <div className={`flex ${isMine ? "justify-end" : "justify-start"}`}>
        <p className="rounded-2xl bg-white px-4 py-2 text-sm italic text-gray-400 shadow-sm">
          {t("chatDetail.deleted")}
        </p>
      </div>
    );
  }
  return (
    <div className={`flex flex-col ${isMine ? "items-end" : "items-start"}`}>
      <div
        className={`max-w-[75%] rounded-2xl px-4 py-2 shadow-sm ${
          isMine ? "bg-[var(--brand-purple)] text-white" : "bg-white text-[var(--brand-navy)] border border-[var(--line)]"
        }`}
      >
        {message.image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={message.image_url} alt="" className="max-w-full rounded-xl" />
        ) : (
          <p className="whitespace-pre-wrap">{message.body}</p>
        )}
      </div>
      <div className="mt-1 flex items-center gap-2">
        <p className="text-[10px] text-gray-400">{messageTime(message.created_at)}</p>
        {isMine && (
          <button
            onClick={() => {
              if (confirm(t("chatDetail.confirmUnsend"))) onUnsend();
            }}
            className="text-xs text-gray-300 hover:text-gray-500"
          >
            {t("chatDetail.unsend")}
          </button>
        )}
      </div>
    </div>
  );
}
