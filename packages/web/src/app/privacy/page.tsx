import type { Metadata } from "next";
import { Crumbs, DocPage, DocTitle } from "@/components/doc/DocPage";
import { TopBar } from "@/components/shell/TopBar";

export const metadata: Metadata = {
  title: "Privacy — ServoMap",
  description: "What ServoMap does with your location and data on the web and on iPhone.",
  alternates: { canonical: "/privacy" },
};

/**
 * The privacy policy linked from the App Store listing. It describes what the code does today;
 * change it in the same pull request as anything that changes what leaves the device.
 */
export default function PrivacyPage() {
  return (
    <DocPage topBar={<TopBar active={null} />}>
      <Crumbs items={[{ label: "Privacy" }]} />
      <div className="grid gap-2">
        <p className="caption">Last updated 29 September 2026</p>
        <DocTitle>Privacy</DocTitle>
      </div>

      <section className="grid gap-4 text-ink-2">
        <p>
          ServoMap has no accounts, no advertising and no tracking. This page covers the website
          and the iPhone app.
        </p>
      </section>

      <Section title="Your location">
        <p>
          If you allow it, your device&rsquo;s location is used to find stations near you. The
          app or website sends the coordinates to the ServoMap API (api.servo-map.com) with the
          request for nearby prices. The API answers the request and does not store or log the
          coordinates. You can use ServoMap without sharing your location by searching for a
          suburb instead.
        </p>
      </Section>

      <Section title="What stays on your device">
        <p>
          Saved stations, your fill-up log, your car profile and recent searches are kept on your
          device only. They are not sent to us. Deleting the app, or clearing the website&rsquo;s
          data in your browser, removes them.
        </p>
      </Section>

      <Section title="Notifications">
        <p>
          If you turn on price alerts in the iPhone app, Apple issues your device a notification
          token. ServoMap keeps it on your device; it will be sent to our server only when price
          alerts go live, and only to send you those alerts. You can turn notifications off at any
          time in Settings.
        </p>
      </Section>

      <Section title="Services we rely on">
        <ul className="grid gap-2 list-disc pl-5">
          <li>
            The website is hosted on Vercel and uses Vercel Web Analytics, which counts page views
            without cookies and without identifying you.
          </li>
          <li>
            The website&rsquo;s map is drawn by Mapbox, which receives your IP address and the
            area of the map you view. The iPhone app uses Apple Maps.
          </li>
          <li>
            The API runs on Cloudflare, which processes requests, including your IP address, to
            deliver them.
          </li>
        </ul>
      </Section>

      <Section title="Contact">
        <p>
          Questions about privacy go to the{" "}
          <a href="https://github.com/Misoto22/servo-map/issues" className="link">
            ServoMap issue tracker
          </a>
          .
        </p>
      </Section>
    </DocPage>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="grid gap-4 text-ink-2">
      <h2 className="font-display text-heading font-semibold text-ink">{title}</h2>
      {children}
    </section>
  );
}
