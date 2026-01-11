'use client';

import ProtectedRoute from '@/components/ProtectedRoute';
import { useTheme } from '@/contexts/ThemeContext';

export default function TenantSettingsPage() {
  const { theme } = useTheme();

  const cardClass = theme === 'cyber' 
    ? 'terminal-card rounded-lg p-6' 
    : 'bg-slate-800 rounded-lg p-6 border border-slate-700';

  return (
    <ProtectedRoute>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold mb-2" style={{ color: 'var(--text-primary)' }}>
            Tenant Settings
          </h1>
          <p style={{ color: 'var(--text-secondary)' }}>
            Manage your tenant configuration, API keys, and agent settings
          </p>
        </div>

        {/* Placeholder Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Tenant Information */}
          <div 
            className={cardClass}
            style={{ 
              background: 'var(--card-bg)',
              border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
            }}
          >
            {theme === 'cyber' && (
              <div className="terminal-dots">
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
              </div>
            )}
            <h2 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
              🏢 Tenant Information
            </h2>
            <p className="text-sm mb-4" style={{ color: 'var(--text-secondary)' }}>
              View and update tenant details
            </p>
            <div className="text-xs" style={{ color: '#94a3b8' }}>
              Coming in Phase 2C
            </div>
          </div>

          {/* API Keys */}
          <div 
            className={cardClass}
            style={{ 
              background: 'var(--card-bg)',
              border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined,
              opacity: 0.6,
            }}
          >
            {theme === 'cyber' && (
              <div className="terminal-dots">
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
              </div>
            )}
            <h2 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
              🔑 API Keys
            </h2>
            <p className="text-sm mb-4" style={{ color: 'var(--text-secondary)' }}>
              Manage API keys for agent registration
            </p>
            <div className="text-xs" style={{ color: '#94a3b8' }}>
              Coming in Phase 2C
            </div>
          </div>

          {/* Agent Configuration */}
          <div 
            className={cardClass}
            style={{ 
              background: 'var(--card-bg)',
              border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
            }}
          >
            {theme === 'cyber' && (
              <div className="terminal-dots">
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
              </div>
            )}
            <h2 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
              📡 Agent Configuration
            </h2>
            <p className="text-sm mb-4" style={{ color: 'var(--text-secondary)' }}>
              Configure agent settings and thresholds
            </p>
            <div className="text-xs" style={{ color: '#94a3b8' }}>
              Coming in Phase 2C
            </div>
          </div>

          {/* Notification Settings */}
          <div 
            className={cardClass}
            style={{ 
              background: 'var(--card-bg)',
              border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
            }}
          >
            {theme === 'cyber' && (
              <div className="terminal-dots">
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
              </div>
            )}
            <h2 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
              🔔 Notification Settings
            </h2>
            <p className="text-sm mb-4" style={{ color: 'var(--text-secondary)' }}>
              Configure alert notifications and channels
            </p>
            <div className="text-xs" style={{ color: '#94a3b8' }}>
              Coming in Phase 2C
            </div>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
