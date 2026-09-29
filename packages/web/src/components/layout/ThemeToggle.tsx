"use client";

import { useTheme } from "@/providers/ThemeProvider";
import { Icon } from "@/components/ui/Icon";

export function ThemeToggle() {
  const { theme, toggle } = useTheme();

  return (
    <button
      type="button"
      onClick={toggle}
      // aria-pressed 表示「浅色模式已开启」，配合 aria-label 让屏幕阅读器知道当前态与动作
      aria-pressed={theme === "light"}
      className="icon-btn"
      aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}
    >
      <Icon name={theme === "dark" ? "sun" : "moon"} />
    </button>
  );
}
