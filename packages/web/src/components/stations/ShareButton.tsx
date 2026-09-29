"use client";

import { useState, useCallback } from "react";
import { cn } from "@/lib/utils";
import { Icon } from "@/components/ui/Icon";

interface ShareButtonProps {
  /** 要分享的标题（站名 + 品牌） */
  title: string;
  /** 分享的相对路径，如 /station/nsw-123 */
  path: string;
  /** Icon only, for tight action rows; the accessible name stays "Share this station". */
  iconOnly?: boolean;
  className?: string;
}

/**
 * 分享按钮：优先用 Web Share API（移动端原生分享），
 * 不支持时回退到复制链接到剪贴板并给出短暂的 "Copied" 反馈。
 */
export function ShareButton({ title, path, iconOnly = false, className }: ShareButtonProps) {
  const [copied, setCopied] = useState(false);

  const handleShare = useCallback(async () => {
    // 运行时才能拿到绝对地址（SSR 阶段没有 window）
    const url = `${window.location.origin}${path}`;

    if (navigator.share) {
      try {
        await navigator.share({ title, url });
        return;
      } catch (err) {
        // 用户取消分享（AbortError）→ 静默返回，不回退到复制
        if (err instanceof DOMException && err.name === "AbortError") return;
        // 其它失败 → 继续走复制回退
      }
    }

    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // 剪贴板也不可用（无权限/非安全上下文）→ 无声失败，避免抛错
    }
  }, [title, path]);

  return (
    <button
      type="button"
      onClick={handleShare}
      className={cn("btn btn-secondary", className)}
      aria-label="Share this station"
    >
      {copied ? (
        <>
          <Icon name="check" />
          {!iconOnly && "Link copied"}
        </>
      ) : (
        <>
          <Icon name="share" />
          {!iconOnly && "Share"}
        </>
      )}
    </button>
  );
}
