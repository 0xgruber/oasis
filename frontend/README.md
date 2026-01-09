# O.A.S.I.S. SOC Portal (Frontend)

Next.js 14-based frontend for the O.A.S.I.S. SIEM system.

## Features

- **Authentication**: JWT-based login with token management
- **Dashboard**: Overview of system status and metrics
- **Log Viewer**: Browse and search OCSF-normalized logs with pagination
- **Protected Routes**: Automatic redirect for unauthenticated users
- **Dark Theme**: Tailwind CSS with slate color scheme

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **HTTP Client**: Axios
- **State Management**: React Context API
- **Date Handling**: date-fns

## Development

### Local Development

```bash
# Install dependencies
npm install

# Set environment variables
cp .env.local.example .env.local

# Run development server
npm run dev
```

Visit http://localhost:3000

### Default Credentials

```
Username: admin
Password: Admin123!
```

## Environment Variables

Create `.env.local`:

```bash
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

## Project Structure

```
frontend/
├── app/                      # Next.js App Router pages
│   ├── dashboard/           # Protected dashboard routes
│   │   ├── layout.tsx      # Dashboard layout with sidebar
│   │   ├── page.tsx        # Dashboard home
│   │   └── logs/           # Logs viewer
│   │       └── page.tsx
│   ├── login/              # Login page
│   │   └── page.tsx
│   ├── layout.tsx          # Root layout with AuthProvider
│   └── page.tsx            # Landing page (redirects)
├── components/             # Reusable components
│   └── ProtectedRoute.tsx # Auth wrapper
├── contexts/               # React contexts
│   └── AuthContext.tsx    # Authentication state
├── lib/                    # Utilities
│   ├── api.ts             # API client & endpoints
│   └── auth.ts            # JWT token management
└── public/                 # Static assets
```

## API Integration

The frontend connects to the API service:

- **POST /auth/login** - User authentication
- **GET /logs** - Fetch logs with pagination
- **GET /health** - Health check

All requests (except login) require JWT token in `Authorization: Bearer <token>` header.

## Docker

Build and run with Docker Compose (from project root):

```bash
docker compose up -d soc-portal
```

The service will be available at http://localhost:3000

## Building for Production

```bash
# Build production bundle
npm run build

# Start production server
npm start
```

## Features Roadmap

- [ ] Real-time metrics dashboard
- [ ] Advanced log filtering and search
- [ ] Alert management UI
- [ ] Tenant management (for super_admin)
- [ ] User management
- [ ] API key management
- [ ] System settings
- [ ] Dark/light theme toggle

