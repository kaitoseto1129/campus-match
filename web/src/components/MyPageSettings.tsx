"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import type { Profile } from "@/lib/types";

export function MyPageSettings({
  profile,
  onProfileChange,
}: {
  profile: Profile;
  onProfileChange: (profile: Profile) => void;
}) {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [isDeleting, setIsDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const canUsePrivateMode = profile.membership_tier === "vip";

  async function updateToggle(column: "show_like_count" | "private_mode" | "show_online_status", value: boolean) {
    onProfileChange({ ...profile, [column]: value });
    await supabase.from("profiles").update({ [column]: value }).eq("id", profile.id);
  }

  async function handleLogout() {
    if (!confirm(t("myPage.logoutConfirm"))) return;
    await supabase.auth.signOut();
    router.push("/login");
  }

  async function handleDeleteAccount() {
    if (!confirm(`${t("myPage.deleteAccountConfirmTitle")}\n\n${t("myPage.deleteAccountConfirmMessage")}`)) return;
    setIsDeleting(true);
    setDeleteError(null);

    // iOS版 AuthManager.deleteAccount() と同じ: RPCの前にStorage上の写真ファイルを先に消しておく
    // (SQL関数からはStorage APIを呼べないため)。失敗しても致命的ではないので続行する。
    const { data: fileList } = await supabase.storage.from("profile_photos").list(profile.id);
    if (fileList && fileList.length > 0) {
      await supabase.storage
        .from("profile_photos")
        .remove(fileList.map((f) => `${profile.id}/${f.name}`));
    }

    const { error } = await supabase.rpc("delete_own_account");
    if (error) {
      setDeleteError(t("myPage.deleteAccountFailed"));
      setIsDeleting(false);
      return;
    }
    await supabase.auth.signOut();
    router.push("/login");
  }

  return (
    <div>
      <p className="mb-2 px-1 text-sm font-bold text-gray-500">{t("myPage.settings")}</p>

      <div className="card mb-3 flex flex-col divide-y divide-[var(--paper-sunken)]">
        <ToggleRow
          label={t("privacySettings.showLikeCount")}
          checked={profile.show_like_count}
          onChange={(v) => updateToggle("show_like_count", v)}
        />
        <ToggleRow
          label={t("privacySettings.privateMode")}
          checked={profile.private_mode}
          disabled={!canUsePrivateMode}
          lockedLabel={!canUsePrivateMode ? t("privacySettings.privateModeLocked") : undefined}
          onChange={(v) => updateToggle("private_mode", v)}
        />
        <ToggleRow
          label={t("privacySettings.showOnlineStatus")}
          checked={profile.show_online_status}
          onChange={(v) => updateToggle("show_online_status", v)}
        />
      </div>

      <button onClick={handleLogout} className="card mb-3 w-full py-3.5 text-center text-sm font-semibold text-gray-700">
        {t("myPage.logout")}
      </button>

      {deleteError && <p className="mb-2 px-1 text-xs text-red-500">{deleteError}</p>}
      <button
        onClick={handleDeleteAccount}
        disabled={isDeleting}
        className="card w-full py-3.5 text-center text-sm font-semibold text-red-500"
      >
        {isDeleting ? t("myPage.deleting") : t("myPage.deleteAccount")}
      </button>
    </div>
  );
}

function ToggleRow({
  label,
  checked,
  disabled,
  lockedLabel,
  onChange,
}: {
  label: string;
  checked: boolean;
  disabled?: boolean;
  lockedLabel?: string;
  onChange: (v: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-3 p-4">
      <div className="flex min-w-0 items-center gap-2">
        <span className="truncate text-sm text-gray-700">{label}</span>
        {lockedLabel && (
          <span className="shrink-0 rounded-full bg-[var(--paper-sunken)] px-2 py-0.5 text-[10px] font-bold text-[var(--brand-purple-dark)]">
            {lockedLabel}
          </span>
        )}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={`relative h-6 w-11 shrink-0 rounded-full transition disabled:opacity-40 ${
          checked ? "bg-[var(--brand-purple)]" : "bg-gray-200"
        }`}
      >
        <span
          className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${
            checked ? "translate-x-5" : "translate-x-0.5"
          }`}
        />
      </button>
    </div>
  );
}
