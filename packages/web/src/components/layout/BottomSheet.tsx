"use client";

import {
  useState,
  useRef,
  useCallback,
  useEffect,
  type ReactNode,
} from "react";
import { cn } from "@/lib/utils";

type SheetPosition = "collapsed" | "half" | "full";

interface BottomSheetProps {
  children: ReactNode;
  className?: string;
}

// Offsets are measured from the top of the map region the sheet is positioned in,
// which already sits between the top bar and the tab bar.
const POSITIONS = {
  collapsed: "calc(100% - 84px)",
  half: "50%",
  full: "0px",
};

// 键盘/点击循环展开的顺序：collapsed → half → full → collapsed
const NEXT_POSITION: Record<SheetPosition, SheetPosition> = {
  collapsed: "half",
  half: "full",
  full: "collapsed",
};

export function BottomSheet({ children, className }: BottomSheetProps) {
  const [position, setPosition] = useState<SheetPosition>("half");
  const sheetRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef({ startY: 0, startTop: 0, dragging: false });

  const handleDragStart = useCallback((clientY: number) => {
    const sheet = sheetRef.current;
    if (!sheet) return;
    dragRef.current = {
      startY: clientY,
      startTop: sheet.offsetTop,
      dragging: true,
    };
  }, []);

  const handleDragMove = useCallback((clientY: number) => {
    if (!dragRef.current.dragging || !sheetRef.current) return;
    const dy = clientY - dragRef.current.startY;
    const newTop = Math.max(0, dragRef.current.startTop + dy);
    sheetRef.current.style.top = `${newTop}px`;
    sheetRef.current.style.transition = "none";
  }, []);

  const handleDragEnd = useCallback((clientY: number) => {
    if (!dragRef.current.dragging || !sheetRef.current) return;
    dragRef.current.dragging = false;
    sheetRef.current.style.transition = "";

    const sheet = sheetRef.current;
    const ratio = sheet.offsetTop / (sheet.offsetParent?.clientHeight || window.innerHeight);

    if (ratio < 0.25) setPosition("full");
    else if (ratio < 0.65) setPosition("half");
    else setPosition("collapsed");

    sheetRef.current.style.top = "";
  }, []);

  // Touch events
  const onTouchStart = useCallback(
    (e: React.TouchEvent) => handleDragStart(e.touches[0].clientY),
    [handleDragStart],
  );
  const onTouchMove = useCallback(
    (e: React.TouchEvent) => handleDragMove(e.touches[0].clientY),
    [handleDragMove],
  );
  const onTouchEnd = useCallback(
    (e: React.TouchEvent) => handleDragEnd(e.changedTouches[0].clientY),
    [handleDragEnd],
  );

  // Mouse events
  useEffect(() => {
    const onMouseMove = (e: MouseEvent) => handleDragMove(e.clientY);
    const onMouseUp = (e: MouseEvent) => handleDragEnd(e.clientY);
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };
  }, [handleDragMove, handleDragEnd]);

  // 键盘操作手柄：Enter/Space 循环展开，方向键上下精细调整高度
  const handleHandleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      setPosition((p) => NEXT_POSITION[p]);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setPosition((p) => (p === "collapsed" ? "half" : "full"));
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setPosition((p) => (p === "full" ? "half" : "collapsed"));
    }
  }, []);

  const isExpanded = position !== "collapsed";

  return (
    <div
      ref={sheetRef}
      role="dialog"
      aria-label="Station list"
      className={cn(
        "absolute inset-x-0 bottom-0 z-20 flex flex-col bg-surface rounded-t-[12px] border-t border-line transition-[top] duration-(--duration-slow) ease-(--ease-standard) md:hidden",
        className,
      )}
      style={{ top: POSITIONS[position] }}
    >
      {/* 可键盘操作的手柄 — 真实 button，带 aria-expanded，触摸/鼠标拖拽仍可用 */}
      <button
        type="button"
        aria-expanded={isExpanded}
        aria-label={
          isExpanded
            ? "Collapse station panel"
            : "Expand station panel"
        }
        className="w-full py-2 cursor-grab active:cursor-grabbing touch-none"
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onMouseDown={(e) => handleDragStart(e.clientY)}
        onKeyDown={handleHandleKeyDown}
      >
        <span className="block w-8 h-[3px] mx-auto bg-line" />
      </button>

      <div className="min-h-0 flex-1 overflow-y-auto">{children}</div>
    </div>
  );
}
