import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  agentRules: false,
  // Use the TypeScript compiler API to keep large route lists out of the CLI stdout pipe.
  experimental: { useTypeScriptCli: false },
};

export default nextConfig;
