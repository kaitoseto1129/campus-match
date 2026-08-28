"use client";

import { startTransition, useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DetailHeader } from "@/components/DetailHeader";
import { useTranslation } from "@/lib/i18n/LanguageProvider";
import {
  drinkingOptions,
  genderOptions,
  languageOptions,
  majorOptions,
  nationalities as nationalityOptions,
  personalityOptions,
  smokingOptions,
  UNSELECTED_OPTION,
} from "@/lib/constants";
import type { Gender, Profile, ProfilePhoto, University } from "@/lib/types";

export default function ProfileEditPage() {
  const router = useRouter();
  const supabase = createClient();
  const { t } = useTranslation();

  const [userId, setUserId] = useState<string | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [university, setUniversity] = useState<University | null>(null);
  const [photos, setPhotos] = useState<ProfilePhoto[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<number | null>(null);
  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false);

  const MAX_TAGLINE_LENGTH = 20;

  const load = useCallback(async () => {
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
    if (profileRow) {
      setProfile(profileRow as Profile);
      if (profileRow.university_id) {
        const { data: uni } = await supabase
          .from("universities")
          .select("*")
          .eq("id", profileRow.university_id)
          .single();
        if (uni) setUniversity(uni as University);
      }
    }

    const { data: photoRows } = await supabase
      .from("profile_photos")
      .select("*")
      .eq("user_id", user.id)
      .order("order_number", { ascending: true });
    if (photoRows) setPhotos(photoRows as ProfilePhoto[]);

    setIsLoading(false);
  }, [router, supabase]);

  useEffect(() => {
    startTransition(() => {
      load();
    });
  }, [load]);

  function update<K extends keyof Profile>(key: K, value: Profile[K]) {
    setProfile((prev) => (prev ? { ...prev, [key]: value } : prev));
  }

  function toggleInArray(key: "nationalities" | "languages", value: string) {
    setProfile((prev) => {
      if (!prev) return prev;
      const current = prev[key];
      const next = current.includes(value)
        ? current.filter((v) => v !== value)
        : [...current, value];
      return { ...prev, [key]: next };
    });
  }

  async function handleSave() {
    if (!profile || !userId) return;
    setIsSaving(true);
    setErrorMessage(null);
    const { error } = await supabase
      .from("profiles")
      .update({
        name: profile.name,
        description: profile.description,
        gender: profile.gender,
        birthday: profile.birthday,
        area: profile.area,
        city: profile.city,
        major: profile.major === UNSELECTED_OPTION ? null : profile.major,
        nationalities: profile.nationalities,
        tagline: profile.tagline,
        drinking: profile.drinking === UNSELECTED_OPTION ? null : profile.drinking,
        smoking: profile.smoking === UNSELECTED_OPTION ? null : profile.smoking,
        body_type: profile.body_type === UNSELECTED_OPTION ? null : profile.body_type,
        languages: profile.languages,
      })
      .eq("id", userId);
    if (error) {
      setErrorMessage(t("profile.saveError"));
    } else {
      setSavedAt(Date.now());
      setTimeout(() => setSavedAt((prev) => (prev ? null : prev)), 3000);
    }
    setIsSaving(false);
  }

  async function handlePhotoUpload(file: File) {
    if (!userId || isUploadingPhoto) return;
    setIsUploadingPhoto(true);
    setErrorMessage(null);
    const ext = file.name.split(".").pop() ?? "jpg";
    const photoId = crypto.randomUUID();
    const path = `${userId}/${photoId}.${ext}`;
    const { error: uploadError } = await supabase.storage
      .from("profile_photos")
      .upload(path, file, { upsert: true });
    if (uploadError) {
      setErrorMessage(t("profile.photoUploadError"));
      setIsUploadingPhoto(false);
      return;
    }
    const {
      data: { publicUrl },
    } = supabase.storage.from("profile_photos").getPublicUrl(path);
    const { error: insertError } = await supabase.from("profile_photos").insert({
      id: photoId,
      user_id: userId,
      url: publicUrl,
      order_number: photos.length,
    });
    if (!insertError) {
      setPhotos((prev) => [...prev, { id: photoId, user_id: userId, url: publicUrl, order_number: prev.length }]);
    }
    setIsUploadingPhoto(false);
  }

  async function handlePhotoDelete(photo: ProfilePhoto) {
    if (!userId) return;
    if (!confirm(t("profile.confirmDeletePhoto"))) return;
    const path = photo.url.split(`/profile_photos/`).pop();
    const { error: deleteRowError } = await supabase.from("profile_photos").delete().eq("id", photo.id);
    if (deleteRowError) {
      setErrorMessage(t("profile.photoDeleteError"));
      return;
    }
    if (path) {
      await supabase.storage.from("profile_photos").remove([path]);
    }
    const remaining = photos.filter((p) => p.id !== photo.id);
    await Promise.all(
      remaining.map((p, index) =>
        p.order_number === index
          ? Promise.resolve()
          : supabase.from("profile_photos").update({ order_number: index }).eq("id", p.id)
      )
    );
    setPhotos(remaining.map((p, index) => ({ ...p, order_number: index })));
  }

  async function handleSetMainPhoto(photo: ProfilePhoto) {
    if (!userId || photo.order_number === 0) return;
    const others = photos.filter((p) => p.id !== photo.id);
    const reordered = [photo, ...others];
    await Promise.all(
      reordered.map((p, index) =>
        p.order_number === index
          ? Promise.resolve()
          : supabase.from("profile_photos").update({ order_number: index }).eq("id", p.id)
      )
    );
    setPhotos(reordered.map((p, index) => ({ ...p, order_number: index })));
  }

  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
      </main>
    );
  }

  if (!profile) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-gray-400">{t("profile.loadError")}</p>
      </main>
    );
  }

  return (
    <div className="app-list-background min-h-screen">
      <DetailHeader title={t("profile.title")} />
      <main className="mx-auto w-full max-w-lg px-5 py-6 sm:px-8">
        {university && <p className="mb-4 text-sm text-gray-400">🎓 {university.name}</p>}
      <div className="card p-5">
      <section className="mb-6">
        <h2 className="mb-2 text-sm font-bold text-gray-500">{t("profile.photos")}</h2>
        <div className="flex flex-wrap gap-3">
          {photos.map((photo, index) => (
            <div key={photo.id} className="group relative">
              <img
                src={photo.url}
                alt=""
                className={`h-24 w-24 rounded-2xl object-cover ${index === 0 ? "ring-2 ring-[var(--brand-purple)] ring-offset-2" : ""}`}
              />
              {index === 0 ? (
                <span className="brand-gradient absolute -top-2 left-1 rounded-full px-2 py-0.5 text-[10px] font-bold text-white shadow">
                  {t("profile.main")}
                </span>
              ) : (
                <button
                  type="button"
                  onClick={() => handleSetMainPhoto(photo)}
                  className="absolute -top-2 left-1 rounded-full bg-white px-2 py-0.5 text-[10px] font-bold text-[var(--brand-purple-dark)] opacity-0 shadow transition group-hover:opacity-100"
                >
                  {t("profile.makeMain")}
                </button>
              )}
              <button
                type="button"
                onClick={() => handlePhotoDelete(photo)}
                aria-label={t("profile.removePhoto")}
                className="absolute -top-2 -right-2 flex h-6 w-6 items-center justify-center rounded-full bg-white text-xs font-bold text-red-500 shadow"
              >
                ×
              </button>
            </div>
          ))}
          {photos.length < 4 && (
            <label
              className={`flex h-24 w-24 items-center justify-center rounded-2xl border-2 border-dashed border-[#e7e4f5] text-2xl text-[var(--brand-purple)] transition ${
                isUploadingPhoto ? "cursor-not-allowed opacity-60" : "cursor-pointer hover:bg-[#f8f7fd]"
              }`}
            >
              {isUploadingPhoto ? (
                <span className="h-5 w-5 animate-spin rounded-full border-2 border-[var(--brand-purple)] border-t-transparent" />
              ) : (
                "+"
              )}
              <input
                type="file"
                accept="image/*"
                className="hidden"
                disabled={isUploadingPhoto}
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) handlePhotoUpload(file);
                  e.target.value = "";
                }}
              />
            </label>
          )}
        </div>
      </section>

      <Field label={t("profile.displayName")}>
        <input
          value={profile.name ?? ""}
          onChange={(e) => update("name", e.target.value)}
          className="input"
        />
      </Field>

      <Field label={t("profile.tagline")}>
        <input
          value={profile.tagline ?? ""}
          onChange={(e) => update("tagline", e.target.value.slice(0, MAX_TAGLINE_LENGTH))}
          maxLength={MAX_TAGLINE_LENGTH}
          placeholder={t("profile.taglinePlaceholder")}
          className="input"
        />
        <p className="mt-1 px-1 text-right text-xs text-gray-400">
          {t("profile.taglineCounter", { count: (profile.tagline ?? "").length, max: MAX_TAGLINE_LENGTH })}
        </p>
      </Field>

      <Field label={t("profile.description")}>
        <textarea
          value={profile.description ?? ""}
          onChange={(e) => update("description", e.target.value)}
          rows={4}
          className="input"
        />
      </Field>

      <Field label={t("profile.gender")}>
        <select
          value={profile.gender ?? ""}
          onChange={(e) => update("gender", e.target.value as Gender)}
          className="input"
        >
          <option value="" disabled>
            {t("profile.genderPlaceholder")}
          </option>
          {genderOptions.map((g) => (
            <option key={g.value} value={g.value}>
              {g.label}
            </option>
          ))}
        </select>
      </Field>

      <Field label={t("profile.birthday")}>
        <input
          type="date"
          value={profile.birthday ?? ""}
          onChange={(e) => update("birthday", e.target.value)}
          className="input"
        />
      </Field>

      <Field label={t("profile.area")}>
        <input
          value={profile.area ?? ""}
          onChange={(e) => update("area", e.target.value)}
          className="input"
        />
      </Field>

      <SelectField
        label={t("profile.major")}
        value={profile.major ?? UNSELECTED_OPTION}
        options={majorOptions}
        unsetLabel={t("profile.unset")}
        onChange={(v) => update("major", v)}
      />

      <SelectField
        label={t("profile.personality")}
        value={profile.body_type ?? UNSELECTED_OPTION}
        options={personalityOptions}
        unsetLabel={t("profile.unset")}
        onChange={(v) => update("body_type", v)}
      />

      <SelectField
        label={t("profile.drinking")}
        value={profile.drinking ?? UNSELECTED_OPTION}
        options={drinkingOptions}
        unsetLabel={t("profile.unset")}
        onChange={(v) => update("drinking", v)}
      />

      <SelectField
        label={t("profile.smoking")}
        value={profile.smoking ?? UNSELECTED_OPTION}
        options={smokingOptions}
        unsetLabel={t("profile.unset")}
        onChange={(v) => update("smoking", v)}
      />

      <Field label={t("profile.nationality")}>
        <MultiSelect
          options={nationalityOptions}
          selected={profile.nationalities}
          onToggle={(v) => toggleInArray("nationalities", v)}
        />
      </Field>

      <Field label={t("profile.languages")}>
        <MultiSelect
          options={languageOptions}
          selected={profile.languages}
          onToggle={(v) => toggleInArray("languages", v)}
        />
      </Field>

      {errorMessage && <p className="mb-4 text-sm text-red-500">{errorMessage}</p>}
      {savedAt && <p className="mb-4 text-sm font-semibold text-[var(--brand-teal)]">{t("profile.saved")}</p>}

      <button onClick={handleSave} disabled={isSaving} className="btn-primary w-full py-3.5">
        {isSaving ? t("common.saving") : t("profile.save")}
      </button>
      </div>
      </main>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="mb-4">
      <label className="mb-1 block text-sm font-bold text-gray-500">{label}</label>
      {children}
    </div>
  );
}

function SelectField({
  label,
  value,
  options,
  unsetLabel,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  unsetLabel: string;
  onChange: (v: string) => void;
}) {
  return (
    <Field label={label}>
      <select value={value} onChange={(e) => onChange(e.target.value)} className="input">
        {options.map((option) => (
          <option key={option} value={option}>
            {option === UNSELECTED_OPTION ? unsetLabel : option}
          </option>
        ))}
      </select>
    </Field>
  );
}

function MultiSelect({
  options,
  selected,
  onToggle,
}: {
  options: string[];
  selected: string[];
  onToggle: (v: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
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
