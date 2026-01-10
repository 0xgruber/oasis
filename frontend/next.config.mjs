/** @type {import('next').NextConfig} */
const API_INTERNAL_URL = process.env.API_INTERNAL_URL || 'http://api-service:8000';

const allowedDevOrigins = (process.env.ALLOWED_DEV_ORIGINS || 'http://localhost:3000,http://127.0.0.1:3000')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const nextConfig = {
  // Allows accessing dev server over non-localhost origins (e.g. Tailscale).
  allowedDevOrigins,

  async rewrites() {
    // Proxy browser calls through Next.js to avoid CORS and hard-coded host IPs.
    return [
      {
        source: '/api/:path*',
        destination: `${API_INTERNAL_URL}/:path*`,
      },
    ];
  },
};

export default nextConfig;
