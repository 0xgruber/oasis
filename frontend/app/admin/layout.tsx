'use client';

import { ReactNode } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import AdminSidebar from '@/components/AdminSidebar';

/**
 * Admin Portal Layout
 * 
 * Wraps admin pages with sidebar navigation
 * Ensures only platform_admin users can access
 */
export default function AdminLayout({ children }: { children: ReactNode }) {
  const { user, isLoading } = useAuth();
  const { theme } = useTheme();
  const router = useRouter();

  // Client-side credential check (belt-and-suspenders with middleware)
  useEffect(() => {
    if (!isLoading && user && user.credential_type !== 'platform_admin') {
      router.push('/login?error=access_denied');
    }
  }, [user, isLoading, router]);

  // Don't render until we've verified the user
  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2" style={{ borderColor: 'var(--primary)' }}></div>
      </div>
    );
  }

  // Only render for platform_admin
  if (!user || user.credential_type !== 'platform_admin') {
    return null;
  }

  return (
    <div className="min-h-screen" style={{ background: 'var(--background)' }}>
      {/* Sidebar */}
      <AdminSidebar />

      {/* Main Content */}
      <div className="ml-64">
        <div className="p-8">
          {children}
        </div>
      </div>
    </div>
  );
}
