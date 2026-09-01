"use client";

import { useEffect, useState } from "react";
import type { AnchorRect } from "@/lib/useTutorialAnchors";

// iOS版 DiscoverTutorialOverlay/GatheringTutorialOverlay/MyPageTutorialOverlay と同じ、
// 実UIの要素だけくり抜いて操作できるようにするスポットライト演出。
// SVGマスクの代わりに、くり抜きたい矩形と同じ大きさの透明な要素に
// box-shadowで画面全体を覆う手法(CSSスポットライトの定番テクニック)を使う。
export function TutorialSpotlight({
  rect,
  message,
  onSkip,
  nextLabel,
  onNext,
  children,
}: {
  rect: AnchorRect | null;
  message: string;
  onSkip: () => void;
  nextLabel?: string;
  onNext?: () => void;
  children?: React.ReactNode;
}) {
  const [pulse, setPulse] = useState(false);
  useEffect(() => {
    const id = setInterval(() => setPulse((p) => !p), 900);
    return () => clearInterval(id);
  }, []);

  const inset = rect ? { top: rect.top - 8, left: rect.left - 8, width: rect.width + 16, height: rect.height + 16 } : null;
  const placeBelow = !rect || rect.top + rect.height / 2 < window.innerHeight / 2;

  return (
    <div className="pointer-events-none fixed inset-0 z-[100]">
      {inset && (
        <div
          className="pointer-events-none absolute rounded-[22px] transition-all duration-300"
          style={{
            top: inset.top,
            left: inset.left,
            width: inset.width,
            height: inset.height,
            boxShadow: "0 0 0 9999px rgba(0,0,0,0.68)",
          }}
        />
      )}
      {!inset && <div className="absolute inset-0 bg-black/68" />}

      {inset && (
        <>
          <div
            className="pointer-events-none absolute rounded-[22px] border-[3px] border-[var(--brand-purple)] shadow-[0_0_10px_rgba(124,58,237,0.6)] transition-all duration-300"
            style={{ top: inset.top, left: inset.left, width: inset.width, height: inset.height }}
          />
          <div
            className={`pointer-events-none absolute rounded-[22px] border-[3px] border-[var(--brand-orange)] transition-all duration-500 ${
              pulse ? "scale-110 opacity-0" : "scale-100 opacity-100"
            }`}
            style={{ top: inset.top, left: inset.left, width: inset.width, height: inset.height }}
          />
        </>
      )}

      <div
        className="pointer-events-none fixed left-1/2 max-w-md -translate-x-1/2 px-8"
        style={
          rect
            ? placeBelow
              ? { top: Math.min(rect.top + rect.height + 70, window.innerHeight - 140) }
              : { top: Math.max(rect.top - 130, 90) }
            : { top: "40%" }
        }
      >
        <div className="rounded-2xl bg-[var(--brand-purple)] p-4 text-center text-sm font-bold text-white shadow-xl">
          {message}
          {nextLabel && onNext && (
            <div className="pointer-events-auto mt-3">
              <button
                onClick={onNext}
                className="rounded-full bg-white px-4 py-2 text-xs font-bold text-[var(--brand-purple-dark)]"
              >
                {nextLabel}
              </button>
            </div>
          )}
        </div>
      </div>

      {children}

      <div className="fixed top-14 right-5 z-10">
        <button
          onClick={onSkip}
          className="rounded-full bg-black/35 px-3.5 py-2 text-xs font-bold text-white/90"
        >
          スキップ
        </button>
      </div>
    </div>
  );
}

export function TutorialClosingCard({
  emoji,
  title,
  description,
  buttonLabel,
  onFinish,
}: {
  emoji: string;
  title: string;
  description?: string;
  buttonLabel: string;
  onFinish: () => void;
}) {
  return (
    <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-4 bg-black/75 px-8 text-center">
      <p className="text-4xl">{emoji}</p>
      <p className="text-xl font-bold text-white">{title}</p>
      {description && <p className="text-sm text-white/85">{description}</p>}
      <button
        onClick={onFinish}
        className="brand-gradient mt-2 w-52 rounded-full py-3.5 font-bold text-white"
      >
        {buttonLabel}
      </button>
    </div>
  );
}
