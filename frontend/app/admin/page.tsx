'use client';

import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import ProtectedRoute from '@/components/ProtectedRoute';
import Link from 'next/link';

/**
 * Admin Portal Home Page
 * 
 * Landing page for platform administrators
 * Shows overview and quick links to admin functions
 */
export default function AdminHomePage() {
  const { user } = useAuth();
  const { theme } = useTheme();

  const adminSections = [
    {
      title: 'User Management',
      description: 'Manage user accounts, roles, and permissions',
      href: '/admin/users',
      icon: '👥',
      color: theme === 'cyber' ? 'var(--primary)' : '#3b82f6',
    },
    {
      title: 'System Settings',
      description: 'Configure global system defaults and thresholds',
      href: '/admin/settings',
      icon: '⚙️',
      color: theme === 'cyber' ? 'var(--primary)' : '#8b5cf6',
    },
    {
      title: 'Tenant Management',
      description: 'Manage tenants, API keys, and configurations',
      href: '/dashboard/settings',
      icon: '🏢',
      color: theme === 'cyber' ? 'var(--primary)' : '#10b981',
    },
    {
      title: 'Agent Monitoring',
      description: 'View and manage all agents across tenants (Coming in Phase 2B)',
      href: '#',
      icon: '📡',
      color: '#94a3b8',
      disabled: true,
    },
    {
      title: 'Audit Logs',
      description: 'View audit trail of all sensitive operations (Coming in Phase 2E)',
      href: '#',
      icon: '📋',
      color: '#94a3b8',
      disabled: true,
    },
    {
      title: 'API Keys',
      description: 'Global API key management and monitoring',
      href: '/dashboard/settings',
      icon: '🔑',
      color: theme === 'cyber' ? 'var(--primary)' : '#f59e0b',
    },
  ];

  const cardClass = theme === 'cyber' 
    ? 'terminal-card rounded-lg p-6' 
    : 'bg-slate-800 rounded-lg p-6 border border-slate-700';

  return (
    <ProtectedRoute>
      <div className="space-y-6">
        {/* Welcome Section */}
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
          <h1 
            className={`text-2xl font-bold mb-2 ${theme === 'cyber' ? 'text-glow-subtle' : 'text-white'}`}
            style={{ color: 'var(--text-primary)' }}
          >
            Platform Administration
          </h1>
          <p style={{ color: 'var(--text-secondary)' }}>
            Welcome, {user?.username}. You have full administrative access to the O.A.S.I.S. platform.
          </p>
        </div>

        {/* Admin Functions Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {adminSections.map((section) => (
            <Link
              key={section.title}
              href={section.disabled ? '#' : section.href}
              className={`${cardClass} transition-all duration-200 ${
                section.disabled 
                  ? 'opacity-50 cursor-not-allowed' 
                  : 'hover:scale-105 cursor-pointer'
              }`}
              style={{ 
                background: 'var(--card-bg)',
                border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined,
                textDecoration: 'none',
              }}
              onClick={(e) => section.disabled && e.preventDefault()}
            >
              {theme === 'cyber' && (
                <div className="terminal-dots">
                  <div className="terminal-dot"></div>
                  <div className="terminal-dot"></div>
                  <div className="terminal-dot"></div>
                </div>
              )}
              
              <div className="flex items-start gap-4">
                <div 
                  className="text-4xl flex-shrink-0"
                  style={{ 
                    filter: section.disabled ? 'grayscale(100%)' : 'none',
                  }}
                >
                  {section.icon}
                </div>
                <div className="flex-1">
                  <h3 
                    className={`text-lg font-semibold mb-2 ${theme === 'cyber' ? 'text-glow-subtle' : ''}`}
                    style={{ color: section.disabled ? '#94a3b8' : 'var(--text-primary)' }}
                  >
                    {section.title}
                  </h3>
                  <p 
                    className="text-sm"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    {section.description}
                  </p>
                </div>
              </div>

              {!section.disabled && (
                <div 
                  className="mt-4 text-sm font-medium flex items-center gap-2"
                  style={{ color: section.color }}
                >
                  <span>Access</span>
                  <span>→</span>
                </div>
              )}
            </Link>
          ))}
        </div>

        {/* System Info */}
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
          <h2 
            className={`text-lg font-semibold mb-4 ${theme === 'cyber' ? 'text-glow-subtle' : ''}`}
            style={{ color: 'var(--text-primary)' }}
          >
            Platform Information
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Version</p>
              <p className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>Phase 2A</p>
            </div>
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Role</p>
              <p className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>Platform Admin</p>
            </div>
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Portal Mode</p>
              <p className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>Three-Portal</p>
            </div>
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Status</p>
              <p 
                className="text-lg font-semibold" 
                style={{ color: theme === 'cyber' ? 'var(--primary)' : '#10b981' }}
              >
                Operational
              </p>
            </div>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
