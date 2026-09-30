import { nswAdapter } from "./nsw";
import { qldAdapter } from "./qld";
import { tasAdapter } from "./tas";
import { waAdapter } from "./wa";
import type { StateAdapter } from "./types";

/** All active adapters for Phase 1 */
export const adapters: readonly StateAdapter[] = [nswAdapter, tasAdapter, qldAdapter, waAdapter];

export type { StateAdapter } from "./types";
