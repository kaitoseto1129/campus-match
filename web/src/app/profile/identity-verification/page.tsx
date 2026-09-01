"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

type VerificationStatus = "unverified" | "pending" | "verified" | "rejected";

interface VerificationRow {
  status: VerificationStatus;
  submitted_at: string | null;
}

export default function IdentityVerificationPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const [userId, setUserId] = useState<string | null>(null);
  const [verification, setVerification] = useState<VerificationRow | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isUploading, setIsUploading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    setIsLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }
    setUserId(user.id);
    const { data } = await supabase
      .from("identity_verifications")
      .select("status, submitted_at")
      .eq("user_id", user.id)
      .maybeSingle();
    setVerification((data as VerificationRow) ?? null);
    setIsLoading(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router, supabase]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleFileSelected(file: File) {
    if (!userId || isUploading) return;
    setIsUploading(true);
    setErrorMessage(null);
    const ext = file.name.split(".").pop() ?? "jpg";
    const path = `${userId}/${crypto.randomUUID()}.${ext}`;
    const { error: uploadError } = await supabase.storage
      .from("identity_documents")
      .upload(path, file, { upsert: false });
    if (uploadError) {
      setErrorMessage(t("identityVerification.uploadError"));
      setIsUploading(false);
      return;
    }
    const { error: upsertError } = await supabase
      .from("identity_verifications")
      .upsert({ user_id: userId, document_path: path }, { onConflict: "user_id" });
    setIsUploading(false);
    if (upsertError) {
      setErrorMessage(t("identityVerification.uploadError"));
      return;
    }
    setVerification({ status: "pending", submitted_at: new Date().toISOString() });
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  const status = verification?.status ?? "unverified";

  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("identityVerification.title")} />
      <main className="mx-auto flex w-full max-w-lg flex-col gap-4 px-5 py-6 sm:px-8">
        <div className="card p-4">
          <p className="mb-1.5 font-bold text-[var(--brand-navy)]">{t("identityVerification.whyTitle")}</p>
          <p className="text-sm text-gray-500">{t("identityVerification.whyBody")}</p>
        </div>

        <StatusBanner status={status} t={t} />

        <div className="card p-4">
          <p className="mb-1.5 font-bold text-[var(--brand-navy)]">{t("identityVerification.uploadTitle")}</p>
          <p className="mb-3 text-sm text-gray-500">{t("identityVerification.uploadBody")}</p>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handleFileSelected(file);
              e.target.value = "";
            }}
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={isUploading || status === "verified"}
            className="btn-primary w-full py-3 text-sm disabled:opacity-40"
          >
            {isUploading
              ? t("identityVerification.uploading")
              : status === "unverified"
                ? t("identityVerification.uploadButton")
                : t("identityVerification.reuploadButton")}
          </button>
          {errorMessage && <p className="mt-3 text-sm text-red-500">{errorMessage}</p>}
        </div>
      </main>
    </div>
  );
}

function StatusBanner({ status, t }: { status: VerificationStatus; t: (key: string) => string }) {
  const styles: Record<VerificationStatus, string> = {
    unverified: "border-[var(--line)] bg-[var(--paper-sunken)] text-gray-600",
    pending: "border-[var(--brand-orange)]/30 bg-[var(--brand-orange)]/10 text-[var(--brand-orange)]",
    verified: "border-[var(--brand-teal)]/30 bg-[var(--brand-teal)]/10 text-[var(--brand-teal)]",
    rejected: "border-red-200 bg-red-50 text-red-500",
  };
  const icons: Record<VerificationStatus, string> = {
    unverified: "📋",
    pending: "⏳",
    verified: "✅",
    rejected: "⚠️",
  };
  return (
    <div className={`rounded-2xl border p-4 text-sm font-bold ${styles[status]}`}>
      {icons[status]} {t(`identityVerification.status.${status}`)}
    </div>
  );
}
