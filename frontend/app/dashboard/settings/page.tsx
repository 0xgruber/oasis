'use client';

import ProtectedRoute from '@/components/ProtectedRoute';
import { useTheme } from '@/contexts/ThemeContext';

export default function SettingsPage() {
  const { theme } = useTheme();

  return (
    <ProtectedRoute>
      <div className="space-y-4">
        <h1 className="text-2xl font-bold" style={{ color: 'var(--text-primary)' }}>
          Settings
        </h1>
        <div 
          className={`p-4 rounded-lg border ${theme === 'cyber' ? 'terminal-card' : 'bg-slate-800 border-slate-700'}`}
          style={theme === 'professional' ? {} : { 
            background: 'var(--card-bg)', 
            borderColor: 'var(--card-border)' 
          }}
        >
          {theme === 'cyber' && (
            <div className="terminal-dots">
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
            </div>
          )}
          <p style={{ color: 'var(--text-secondary)' }}>
            Settings is not implemented yet. This will include API keys, tenants, and user management.
          </p>
        </div>
      </div>
    </ProtectedRoute>
  );
}
