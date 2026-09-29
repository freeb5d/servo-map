import { defaultTheme } from "@servo-map/design-tokens";

export type Theme = "light" | "dark";

/** localStorage key holding the viewer's explicit theme choice. */
export const THEME_STORAGE_KEY = "servo-theme";

/**
 * Runs in <head> before first paint: an explicit stored choice wins, otherwise the
 * system preference, so dark-mode viewers never see a flash of the paper theme.
 */
export const THEME_BOOT_SCRIPT = `(function(){var d=document.documentElement,t;try{t=localStorage.getItem(${JSON.stringify(THEME_STORAGE_KEY)})}catch(e){}if(t!=="light"&&t!=="dark"){t=window.matchMedia&&window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":${JSON.stringify(defaultTheme)}}d.setAttribute("data-theme",t)})();`;
