'use client';

import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import ThemeSwitcher from '@/components/ThemeSwitcher';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { user, logout } = useAuth();
  const { theme } = useTheme();
  const pathname = usePathname();

  const navigation = [
    { name: 'Dashboard', href: '/dashboard', icon: '📊' },
    { name: 'Logs', href: '/dashboard/logs', icon: '📝' },
    { name: 'Analytics', href: '/dashboard/analytics', icon: '📈' },
    { name: 'Alerts', href: '/dashboard/alerts', icon: '🔔' },
    { name: 'Settings', href: '/dashboard/settings', icon: '⚙️' },
  ];

  return (
    <div className="min-h-screen" style={{ background: 'var(--background)' }}>
      {/* Sidebar */}
      <div 
        className="fixed inset-y-0 left-0 w-64"
        style={{ 
          background: 'var(--sidebar-bg)', 
          borderRight: `1px solid var(--sidebar-border)` 
        }}
      >
        {/* Logo */}
        <div 
          className="flex items-center h-16 px-6"
          style={{ borderBottom: `1px solid var(--sidebar-border)` }}
        >
          <h1 
            className={`text-xl font-bold ${theme === 'cyber' ? 'glitch-text text-glow' : 'text-white'}`}
            data-text="O.A.S.I.S."
            style={{ color: 'var(--text-primary)' }}
          >
            O.A.S.I.S.
          </h1>
        </div>

        {/* Navigation */}
        <nav className="mt-6 px-3">
          {navigation.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.name}
                href={item.href}
                className={`flex items-center px-3 py-3 mb-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? theme === 'cyber' 
                      ? 'text-white' 
                      : 'bg-blue-600 text-white'
                    : theme === 'cyber'
                      ? 'hover:text-white'
                      : 'text-slate-300 hover:bg-slate-700 hover:text-white'
                }`}
                style={isActive ? { 
                  background: theme === 'cyber' ? 'var(--primary)' : undefined,
                  boxShadow: theme === 'cyber' ? '0 0 20px rgba(0, 255, 159, 0.3)' : undefined,
                  color: theme === 'cyber' ? '#0a0e27' : undefined
                } : {
                  color: theme === 'cyber' ? 'var(--text-secondary)' : undefined
                }}
              >
                <span className="mr-3 text-lg">{item.icon}</span>
                {item.name}
              </Link>
            );
          })}
        </nav>

        {/* User Info */}
        <div 
          className="absolute bottom-0 left-0 right-0 p-4"
          style={{ borderTop: `1px solid var(--sidebar-border)` }}
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center min-w-0 flex-1">
              <div 
                className="w-10 h-10 rounded-full flex items-center justify-center font-semibold mr-3"
                style={{ 
                  background: theme === 'cyber' ? 'var(--primary)' : '#2563eb',
                  color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                  boxShadow: theme === 'cyber' ? '0 0 15px var(--primary)' : undefined
                }}
              >
                {user?.username?.[0]?.toUpperCase() || 'U'}
              </div>
              <div className="min-w-0 flex-1">
                <p 
                  className="text-sm font-medium truncate" 
                  style={{ color: 'var(--text-primary)' }}
                >
                  {user?.username}
                </p>
                <p 
                  className="text-xs truncate" 
                  style={{ color: 'var(--text-secondary)' }}
                >
                  {user?.role}
                </p>
              </div>
            </div>
            <div className="flex items-center ml-2 space-x-2">
              <ThemeSwitcher />
              <button
                onClick={logout}
                className="transition-colors"
                style={{ color: 'var(--text-secondary)' }}
                title="Logout"
                onMouseEnter={(e) => e.currentTarget.style.color = 'var(--text-primary)'}
                onMouseLeave={(e) => e.currentTarget.style.color = 'var(--text-secondary)'}
              >
                🚪
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="pl-64">
        {/* Header */}
        <header 
          className="h-16 flex items-center justify-between px-6"
          style={{ 
            background: 'var(--sidebar-bg)', 
            borderBottom: `1px solid var(--sidebar-border)` 
          }}
        >
          <div>
            <h2 
              className={`text-lg font-semibold ${theme === 'cyber' ? 'text-glow-subtle' : ''}`}
              style={{ color: 'var(--text-primary)' }}
            >
              {navigation.find((item) => item.href === pathname)?.name || 'Dashboard'}
            </h2>
          </div>
          <div className="flex items-center space-x-4">
            <span 
              className="text-sm"
              style={{ color: 'var(--text-secondary)' }}
            >
              Tenant: <span style={{ color: 'var(--text-primary)' }}>{user?.tenant_id?.slice(0, 8)}</span>
            </span>
          </div>
        </header>

        {/* Page Content */}
        <main className="p-6 relative z-10">
          {children}
        </main>
      </div>
    </div>
  );
}
