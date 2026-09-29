import type { Metadata } from "next";
import { SavedView } from "@/components/saved/SavedView";

// Saved stations live in this browser, so the page has nothing for a search engine to index.
export const metadata: Metadata = {
  title: "Saved Stations — ServoMap",
  description: "Your saved fuel stations, ranked by today's price.",
  robots: { index: false, follow: true },
};

export default function SavedPage() {
  return <SavedView />;
}
