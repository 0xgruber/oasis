'use client';

import { ReactNode } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

/**
 * Admin Portal Layout
 * 
 * Wraps admin pages with a consistent header
 * Ensures only platform_admin users can access
 */
export default function AdminLayout({ children }: { children: ReactNode }) {
  const { user, isLoading } = useAuth();
  const { theme } = useTheme();
  const router = useRouter();

  // Client-side role check (belt-and-suspenders with middleware)
  useEffect(() => {
    if (!isLoading && user && user.role !== 'platform_admin') {
      router.push('/dashboard?error=access_denied');
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
  if (!user || user.role !== 'platform_admin') {
    return null;
  }

  return (
    <div>
      {/* Admin Portal Header - shown on all admin pages */}
      <div 
        className="mb-6 p-4 rounded-lg border-2"
        style={{
          background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.05)' : 'rgba(59, 130, 246, 0.05)',
          borderColor: theme === 'cyber' ? 'var(--primary)' : '#3b82f6',
        }}
      >
        <div className="flex items-center gap-3">
          <span style={{ fontSize: '24px' }}>🔒</span>
          <div>
            <h2 
              className="text-sm font-semibold"
              style={{ 
                color: theme === 'cyber' ? 'var(--primary)' : '#3b82f6',
              }}
            >
              Platform Admin Portal
            </h2>
            <p className="text-xs" style={{ color: 'var(--text-secondary)' }}>
              You are accessing administrative functions. Changes here affect the entire platform.
            </p>
          </div>
        </div>
      </div>

      {/* Admin Page Content */}
      {children}
    </div>
  );
}
