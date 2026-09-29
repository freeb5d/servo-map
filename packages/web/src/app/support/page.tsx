import type { Metadata } from "next";
import Link from "next/link";
import { Crumbs, DocPage, DocTitle } from "@/components/doc/DocPage";
import { TopBar } from "@/components/shell/TopBar";

export const metadata: Metadata = {
  title: "Support — ServoMap",
  description: "Help with the ServoMap website and iPhone app, and how to report a problem.",
  alternates: { canonical: "/support" },
};

const ISSUES = "https://github.com/Misoto22/servo-map/issues";

/** The support page linked from the App Store listing. */
export default function SupportPage() {
  return (
    <DocPage topBar={<TopBar active={null} />}>
      <Crumbs items={[{ label: "Support" }]} />
      <DocTitle>Support</DocTitle>

      <section className="grid gap-4 text-ink-2">
        <p>
          To report a wrong price, a missing station or a problem with the app, open an issue on
          the{" "}
          <a href={ISSUES} className="link">
            ServoMap issue tracker
          </a>
          . Include the station or suburb and, for the app, your iOS version.
        </p>
      </section>

      <section className="grid gap-4 text-ink-2">
        <h2 className="font-display text-heading font-semibold text-ink">Common questions</h2>
        <dl className="grid gap-4">
          <div>
            <dt className="font-medium text-ink">Why is a price different at the bowser?</dt>
            <dd>
              Prices come from each state&rsquo;s official reporting scheme and refresh every
              15 minutes, but a station can change its price before it reports. Always check the
              price at the pump.
            </dd>
          </div>
          <div>
            <dt className="font-medium text-ink">Why are there no prices in my state?</dt>
            <dd>
              ServoMap shows states whose price feeds are connected. See{" "}
              <Link href="/about" className="link">
                how ServoMap works
              </Link>{" "}
              for the current list.
            </dd>
          </div>
          <div>
            <dt className="font-medium text-ink">Where are my saved stations and fill-ups?</dt>
            <dd>
              On your device only. They do not sync between devices. See the{" "}
              <Link href="/privacy" className="link">
                privacy page
              </Link>
              .
            </dd>
          </div>
        </dl>
      </section>
    </DocPage>
  );
}
