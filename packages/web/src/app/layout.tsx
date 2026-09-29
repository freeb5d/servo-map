import type { Metadata, Viewport } from "next";
import { Shippori_Mincho, Zen_Kaku_Gothic_New } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import { color } from "@servo-map/design-tokens";
import { ThemeProvider } from "@/providers/ThemeProvider";
import { THEME_BOOT_SCRIPT } from "@/lib/theme";
import { SITE_URL } from "@/lib/site";
import "./globals.css";

// tokens.css resolves var(--font-loaded-*) at :root, so the classes go on <html>.
const shipporiMincho = Shippori_Mincho({
  subsets: ["latin"],
  weight: ["500", "600"],
  variable: "--font-loaded-display",
  display: "swap",
});

const zenKakuGothicNew = Zen_Kaku_Gothic_New({
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  variable: "--font-loaded-body",
  display: "swap",
});

export const metadata: Metadata = {
  title: "ServoMap — Australian Fuel Prices",
  description:
    "Find the cheapest fuel near you. Real-time petrol and diesel prices across Australia.",
  metadataBase: new URL(SITE_URL),
  alternates: { canonical: "/" },
  openGraph: {
    title: "ServoMap — Australian Fuel Prices",
    description: "Find the cheapest fuel near you across Australia.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "ServoMap — Australian Fuel Prices",
    description: "Find the cheapest fuel near you across Australia.",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: color.bg.dark },
    { media: "(prefers-color-scheme: light)", color: color.bg.light },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      data-theme="light"
      className={`${shipporiMincho.variable} ${zenKakuGothicNew.variable}`}
      suppressHydrationWarning
    >
      <head>
        {/* Resolves the stored or system theme before first paint to avoid a flash. */}
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} />
      </head>
      <body className="font-body">
        <ThemeProvider>{children}</ThemeProvider>
        <Analytics />
      </body>
    </html>
  );
}
