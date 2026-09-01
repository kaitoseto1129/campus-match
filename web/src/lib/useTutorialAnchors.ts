"use client";

import { useCallback, useEffect, useRef, useState } from "react";

export type AnchorRect = { top: number; left: number; width: number; height: number };
type Rects = Record<string, AnchorRect>;

// iOS版のtutorialAnchor(PreferenceKeyで実UI要素の位置を集める仕組み)と同じ考え方。
// 実際のDOM要素にref(id)をアタッチすると、その要素の画面上の位置を追跡してくれる。
// スクロール・リサイズのたびに再計測する(毎フレームの再計測は行わない。負荷が大きいため)。
export function useTutorialAnchors() {
  const [rects, setRects] = useState<Rects>({});
  const elements = useRef<Map<string, HTMLElement>>(new Map());
  const lastRef = useRef<Rects>({});

  const measure = useCallback(() => {
    const next: Rects = {};
    elements.current.forEach((el, id) => {
      const r = el.getBoundingClientRect();
      next[id] = { top: r.top, left: r.left, width: r.width, height: r.height };
    });
    const prev = lastRef.current;
    const keys = Object.keys(next);
    const changed =
      keys.length !== Object.keys(prev).length ||
      keys.some((id) => {
        const a = next[id];
        const b = prev[id];
        return !b || a.top !== b.top || a.left !== b.left || a.width !== b.width || a.height !== b.height;
      });
    if (changed) {
      lastRef.current = next;
      setRects(next);
    }
  }, []);

  useEffect(() => {
    const id = requestAnimationFrame(measure);
    window.addEventListener("scroll", measure, { passive: true });
    window.addEventListener("resize", measure);
    return () => {
      cancelAnimationFrame(id);
      window.removeEventListener("scroll", measure);
      window.removeEventListener("resize", measure);
    };
  }, [measure]);

  const refs = useRef<Map<string, (el: HTMLElement | null) => void>>(new Map());
  const ref = useCallback(
    (id: string) => {
      let fn = refs.current.get(id);
      if (!fn) {
        fn = (el: HTMLElement | null) => {
          if (el) elements.current.set(id, el);
          else elements.current.delete(id);
          requestAnimationFrame(measure);
        };
        refs.current.set(id, fn);
      }
      return fn;
    },
    [measure]
  );

  return { rects, ref, measure };
}
