"use client";

import { useEffect, useRef, type RefObject } from "react";

interface DismissOptions {
  onClose: () => void;
  /** The panel; focus moves here on open. */
  panelRef: RefObject<HTMLElement | null>;
  /** The control that opened it: outside clicks on it are ignored and focus returns to it on close. */
  triggerRef: RefObject<HTMLElement | null>;
  closeOnOutsideClick: boolean;
}

/** Esc and outside-click dismissal for a popover, with focus moved in on open and back on close. */
export function useDismiss({ onClose, panelRef, triggerRef, closeOnOutsideClick }: DismissOptions): void {
  // A ref keeps the effect from re-running (and re-stealing focus) when onClose changes identity.
  const closeRef = useRef(onClose);
  useEffect(() => {
    closeRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    const panel = panelRef.current;
    const trigger = triggerRef.current;
    panel?.focus();

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeRef.current();
    };
    const onPointerDown = (e: MouseEvent) => {
      const target = e.target as Node;
      if (!closeOnOutsideClick || panel?.contains(target) || trigger?.contains(target)) return;
      closeRef.current();
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("mousedown", onPointerDown);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("mousedown", onPointerDown);
      trigger?.focus();
    };
  }, [panelRef, triggerRef, closeOnOutsideClick]);
}
