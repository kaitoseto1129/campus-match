"use client";

import { ModerationList } from "@/components/ModerationList";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

export default function HiddenListPage() {
  const { t } = useTranslation();
  return <ModerationList action="hide" title={t("moderation.hiddenTitle")} emptyMessageKey="moderation.hiddenEmpty" />;
}
