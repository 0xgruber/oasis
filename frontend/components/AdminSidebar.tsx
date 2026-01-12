'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';

export default function AdminSidebar() {
  const { user, logout } = useAuth();
  const { theme } = useTheme();
  const pathname = usePathname();

  const navigation = [
    { name: 'Overview', href: '/admin', icon: '🏠', exact: true },
    { name: 'User Management', href: '/admin/users', icon: '👥' },
    { name: 'Agent Management', href: '/admin/agents', icon: '📡' },
    { name: 'System Settings', href: '/admin/settings', icon: '⚙️' },
  ];

  const isActive = (href: string, exact?: boolean) => {
    if (exact) {
      return pathname === href;
    }
    return pathname.startsWith(href);
  };

  return (
    <div 
      className="fixed inset-y-0 left-0 w-64 flex flex-col"
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

      {/* Portal Badge */}
      <div className="px-6 py-4" style={{ borderBottom: `1px solid var(--sidebar-border)` }}>
        <div 
          className="px-3 py-2 rounded-lg text-xs font-semibold text-center"
          style={{
            background: theme === 'cyber' ? 'rgba(138, 43, 226, 0.2)' : 'rgba(139, 92, 246, 0.2)',
            color: theme === 'cyber' ? '#a855f7' : '#a78bfa',
            border: `1px solid ${theme === 'cyber' ? '#a855f7' : '#a78bfa'}`,
          }}
        >
          🔒 ADMIN PORTAL
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 mt-6 px-3 overflow-y-auto">
        {navigation.map((item) => {
          const active = isActive(item.href, item.exact);
          return (
            <Link
              key={item.name}
              href={item.href}
              className={`flex items-center px-3 py-3 mb-2 rounded-lg text-sm font-medium transition-colors ${
                active
                  ? theme === 'cyber' 
                    ? 'text-white' 
                    : 'bg-purple-600 text-white'
                  : theme === 'cyber'
                    ? 'hover:text-white'
                    : 'text-slate-300 hover:bg-slate-700 hover:text-white'
              }`}
              style={active ? { 
                background: theme === 'cyber' ? '#a855f7' : undefined,
                boxShadow: theme === 'cyber' ? '0 0 20px rgba(168, 85, 247, 0.3)' : undefined,
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

      {/* User Info & Logout */}
      <div 
        className="p-4"
        style={{ borderTop: `1px solid var(--sidebar-border)` }}
      >
        <div className="mb-3">
          <div className="text-xs font-semibold" style={{ color: 'var(--text-secondary)' }}>
            Logged in as
          </div>
          <div className="text-sm font-medium mt-1" style={{ color: 'var(--text-primary)' }}>
            {user?.username}
          </div>
          <div className="text-xs mt-1" style={{ color: 'var(--text-secondary)' }}>
            Platform Administrator
          </div>
        </div>
        <button
          onClick={logout}
          className="w-full px-4 py-2 rounded-lg text-sm font-medium transition-colors"
          style={{
            background: theme === 'cyber' ? 'rgba(239, 68, 68, 0.2)' : 'rgba(239, 68, 68, 0.1)',
            color: '#ef4444',
            border: `1px solid #ef4444`,
          }}
        >
          🚪 Logout
        </button>
      </div>
    </div>
  );
}
