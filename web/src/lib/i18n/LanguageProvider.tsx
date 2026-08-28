"use client";

import { createContext, startTransition, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { translations, type Locale } from "./translations";

const STORAGE_KEY = "cammatch:language";

interface LanguageContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
}

const LanguageContext = createContext<LanguageContextValue | null>(null);

function detectInitialLocale(): Locale {
  if (typeof window === "undefined") return "ja";
  const stored = window.localStorage.getItem(STORAGE_KEY);
  if (stored === "ja" || stored === "en") return stored;
  return window.navigator.language.toLowerCase().startsWith("ja") ? "ja" : "en";
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("ja");

  useEffect(() => {
    startTransition(() => {
      setLocaleState(detectInitialLocale());
    });
  }, []);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  function setLocale(next: Locale) {
    setLocaleState(next);
    window.localStorage.setItem(STORAGE_KEY, next);
  }

  const value = useMemo(() => ({ locale, setLocale }), [locale]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

// ドット区切りのキー("login.title" 等)で辞書を引き、{name} 形式のプレースホルダーを置換する。
function resolve(locale: Locale, key: string): string {
  const parts = key.split(".");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let node: any = translations[locale];
  for (const part of parts) {
    node = node?.[part];
  }
  return typeof node === "string" ? node : key;
}

export function useTranslation() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error("useTranslation must be used within a LanguageProvider");
  const { locale, setLocale } = ctx;

  function t(key: string, vars?: Record<string, string | number>): string {
    let text = resolve(locale, key);
    if (vars) {
      for (const [name, val] of Object.entries(vars)) {
        text = text.replaceAll(`{${name}}`, String(val));
      }
    }
    return text;
  }

  return { t, locale, setLocale };
}
