'use client';

import { useState, useRef, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';

interface UserMenuProps {
  username: string;
  onOpenAccountSettings: () => void;
  onOpenThemeSettings: () => void;
}

export default function UserMenu({ username, onOpenAccountSettings, onOpenThemeSettings }: UserMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const { logout } = useAuth();
  const { theme } = useTheme();
  const menuRef = useRef<HTMLDivElement>(null);

  const handleMenuClick = (action: () => void) => {
    setIsOpen(false);
    action();
  };

  // Close menu on click outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  return (
    <div className="relative" ref={menuRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 w-full p-2 rounded-lg transition-colors"
        style={{
          background: isOpen ? 'var(--primary)' : 'transparent',
          color: isOpen ? '#ffffff' : 'var(--text-primary)',
        }}
      >
        <div 
          className="w-8 h-8 rounded-full flex items-center justify-center font-bold"
          style={{
            background: 'var(--primary)',
            color: '#ffffff',
            boxShadow: theme === 'cyber' ? '0 0 15px var(--primary)' : 'none',
          }}
        >
          {username.charAt(0).toUpperCase()}
        </div>
        <span className="text-sm font-medium">{username}</span>
      </button>

      {isOpen && (
        <div
          className="absolute bottom-full left-0 mb-2 w-64 rounded-lg shadow-xl border"
          style={{
            background: 'var(--card-bg)',
            borderColor: 'var(--card-border)',
            boxShadow: theme === 'cyber' 
              ? '0 0 20px rgba(0, 255, 159, 0.3)' 
              : '0 10px 25px rgba(0, 0, 0, 0.3)',
          }}
        >
          <div className="p-2">
            <button
              onClick={() => handleMenuClick(onOpenAccountSettings)}
              className="w-full text-left px-4 py-3 rounded-lg transition-all flex items-center gap-3"
              style={{
                color: 'var(--text-primary)',
                background: 'transparent',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'var(--table-row-hover)';
                if (theme === 'cyber') {
                  e.currentTarget.style.boxShadow = '0 0 10px rgba(0, 255, 159, 0.2)';
                }
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'transparent';
                e.currentTarget.style.boxShadow = 'none';
              }}
            >
              <span className="text-xl">⚙️</span>
              <span className="font-medium">Account Settings</span>
            </button>

            <button
              onClick={() => handleMenuClick(onOpenThemeSettings)}
              className="w-full text-left px-4 py-3 rounded-lg transition-all flex items-center gap-3"
              style={{
                color: 'var(--text-primary)',
                background: 'transparent',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'var(--table-row-hover)';
                if (theme === 'cyber') {
                  e.currentTarget.style.boxShadow = '0 0 10px rgba(0, 255, 159, 0.2)';
                }
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'transparent';
                e.currentTarget.style.boxShadow = 'none';
              }}
            >
              <span className="text-xl">🎨</span>
              <span className="font-medium">Change Theme</span>
            </button>

            <div className="my-2 border-t" style={{ borderColor: 'var(--card-border)' }}></div>

            <button
              onClick={() => handleMenuClick(logout)}
              className="w-full text-left px-4 py-3 rounded-lg transition-all flex items-center gap-3"
              style={{
                color: theme === 'cyber' ? 'var(--cyber-red)' : '#ef4444',
                background: 'transparent',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'var(--table-row-hover)';
                if (theme === 'cyber') {
                  e.currentTarget.style.boxShadow = '0 0 10px rgba(255, 0, 85, 0.2)';
                }
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'transparent';
                e.currentTarget.style.boxShadow = 'none';
              }}
            >
              <span className="text-xl">🚪</span>
              <span className="font-medium">Logout</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
