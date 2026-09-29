import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@servo-map/shared", "@servo-map/design-tokens"],
};

export default nextConfig;
