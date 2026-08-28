"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import { HOBBY_CARD_MAX_SELECTION, hobbyCardCatalog, hobbyCategoryOrder } from "@/lib/hobbyCards";

export default function HobbyCardsPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [userId, setUserId] = useState<string | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

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
      const { data: profileRow } = await supabase.from("profiles").select("hobby_cards").eq("id", user.id).single();
      if (cancelled) return;
      setUserId(user.id);
      setSelected((profileRow?.hobby_cards as string[]) ?? []);
      setIsLoading(false);
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [router, supabase]);

  function toggle(id: string) {
    setSelected((prev) => {
      if (prev.includes(id)) return prev.filter((v) => v !== id);
      if (prev.length >= HOBBY_CARD_MAX_SELECTION) return prev;
      // catalog順で保存する(iOS版と同じ: 選んだ順ではなくカタログの並び順を保つ)。
      const next = new Set(prev);
      next.add(id);
      return hobbyCardCatalog.map((c) => c.id).filter((cid) => next.has(cid));
    });
  }

  async function handleSave() {
    if (!userId || isSaving) return;
    setIsSaving(true);
    await supabase.from("profiles").update({ hobby_cards: selected }).eq("id", userId);
    setIsSaving(false);
    router.back();
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  return (
    <div className="app-list-background min-h-screen pb-28">
      <DetailHeader
        title={t("hobbyCards.title")}
        action={<span className="text-xs font-bold text-gray-400">{selected.length} / {HOBBY_CARD_MAX_SELECTION}</span>}
      />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        {hobbyCategoryOrder.map((category) => (
          <section key={category} className="mb-6">
            <h2 className="mb-2 text-sm font-bold text-gray-500">{category}</h2>
            <div className="flex flex-wrap gap-2">
              {hobbyCardCatalog
                .filter((c) => c.category === category)
                .map((card) => {
                  const isSelected = selected.includes(card.id);
                  const isDisabled = !isSelected && selected.length >= HOBBY_CARD_MAX_SELECTION;
                  return (
                    <button
                      key={card.id}
                      type="button"
                      onClick={() => toggle(card.id)}
                      disabled={isDisabled}
                      className="chip disabled:cursor-not-allowed disabled:opacity-40"
                      data-selected={isSelected}
                    >
                      {card.emoji} {card.title}
                    </button>
                  );
                })}
            </div>
          </section>
        ))}
      </main>
      <div className="fixed inset-x-0 bottom-0 z-30 bg-white px-4 pt-2.5 pb-4 shadow-[0_-6px_14px_rgba(0,0,0,0.16)]">
        <button onClick={handleSave} disabled={isSaving} className="btn-primary w-full py-3.5">
          {isSaving ? t("common.saving") : t("common.save")}
        </button>
      </div>
    </div>
  );
}
