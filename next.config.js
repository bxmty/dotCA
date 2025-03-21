/** @type {import('next').NextConfig} */
const nextConfig = {
  // Config options here
  output: 'standalone',
  // Enable CSS import in server components
  transpilePackages: ['bootstrap'],
  // Image optimization configuration
  images: {
    domains: [],
    remotePatterns: [],
    unoptimized: false,
  },
  // Custom error handling
  experimental: {
    // Disable automatic static error pages
    disableOptimizedLoading: true,
    optimizeCss: false,
  },
};

module.exports = nextConfig;
