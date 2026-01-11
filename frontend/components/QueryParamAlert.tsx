'use client';

import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { useTheme } from '@/contexts/ThemeContext';

/**
 * QueryParamAlert Component
 * 
 * Displays alert messages based on URL query parameters
 * Used by middleware to show access denied messages
 */
export default function QueryParamAlert() {
  const { theme } = useTheme();
  const searchParams = useSearchParams();
  const [alert, setAlert] = useState<{ type: 'error' | 'warning' | 'info'; message: string } | null>(null);

  useEffect(() => {
    // Check for error query parameter
    const error = searchParams.get('error');
    const expired = searchParams.get('expired');

    if (error === 'access_denied') {
      setAlert({
        type: 'error',
        message: 'Access Denied: You do not have permission to access that resource.',
      });
    } else if (error === 'wrong_portal') {
      setAlert({
        type: 'error',
        message: 'Invalid Portal: Please use the customer portal to access your account.',
      });
    } else if (expired === 'true') {
      setAlert({
        type: 'warning',
        message: 'Session Expired: Your session has expired. Please log in again.',
      });
    }

    // Auto-dismiss after 8 seconds
    if (error || expired) {
      const timeout = setTimeout(() => {
        setAlert(null);
        // Clear query params from URL without reloading
        const url = new URL(window.location.href);
        url.searchParams.delete('error');
        url.searchParams.delete('expired');
        window.history.replaceState({}, '', url.pathname);
      }, 8000);

      return () => clearTimeout(timeout);
    }
  }, [searchParams]);

  const handleDismiss = () => {
    setAlert(null);
    // Clear query params from URL
    const url = new URL(window.location.href);
    url.searchParams.delete('error');
    url.searchParams.delete('expired');
    window.history.replaceState({}, '', url.pathname);
  };

  if (!alert) return null;

  const colors = {
    error: {
      bg: 'rgba(239, 68, 68, 0.1)',
      border: 'rgba(239, 68, 68, 0.3)',
      text: '#ef4444',
      icon: '🚫',
    },
    warning: {
      bg: 'rgba(251, 191, 36, 0.1)',
      border: 'rgba(251, 191, 36, 0.3)',
      text: '#fbbf24',
      icon: '⚠️',
    },
    info: {
      bg: theme === 'cyber' ? 'rgba(0, 255, 159, 0.1)' : 'rgba(59, 130, 246, 0.1)',
      border: theme === 'cyber' ? 'rgba(0, 255, 159, 0.3)' : 'rgba(59, 130, 246, 0.3)',
      text: theme === 'cyber' ? 'var(--primary)' : '#3b82f6',
      icon: 'ℹ️',
    },
  };

  const alertColors = colors[alert.type];

  return (
    <div 
      className="mb-6 p-4 rounded-lg animate-fade-in"
      style={{ 
        background: alertColors.bg, 
        border: `1px solid ${alertColors.border}` 
      }}
    >
      <div className="flex items-start gap-3">
        <span style={{ fontSize: '20px' }}>{alertColors.icon}</span>
        <div className="flex-1">
          <p style={{ color: alertColors.text, fontWeight: 500 }}>{alert.message}</p>
        </div>
        <button
          onClick={handleDismiss}
          className="text-sm transition-opacity hover:opacity-80"
          style={{ color: alertColors.text }}
          aria-label="Dismiss alert"
        >
          ✕
        </button>
      </div>
    </div>
  );
}
