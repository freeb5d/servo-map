import type { IconName } from "@/components/ui/Icon";

export type Section = "map" | "trends" | "saved";

/** The three sections of the app, shared by the desktop top bar and the mobile tab bar. */
export const SECTIONS: readonly { id: Section; href: string; label: string; icon: IconName }[] = [
  { id: "map", href: "/", label: "Map", icon: "map" },
  { id: "trends", href: "/trends", label: "Trends", icon: "trend" },
  { id: "saved", href: "/saved", label: "Saved", icon: "bookmark" },
];
