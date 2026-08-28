"use client";

import { ModerationList } from "@/components/ModerationList";
import { useTranslation } from "@/lib/i18n/LanguageProvider";

export default function BlockedListPage() {
  const { t } = useTranslation();
  return <ModerationList action="block" title={t("moderation.blockedTitle")} emptyMessageKey="moderation.blockedEmpty" />;
}
