'use client';

import { useEffect } from 'react';
import { useTheme } from '@/contexts/ThemeContext';

interface ChangeThemeModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function ChangeThemeModal({ isOpen, onClose }: ChangeThemeModalProps) {
  const { theme, setTheme } = useTheme();

  // Close on ESC key
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const handleThemeSelect = (selectedTheme: 'professional' | 'cyber') => {
    setTheme(selectedTheme);
    // Close modal after a brief delay to show the theme change
    setTimeout(() => onClose(), 300);
  };

  return (
    <div
      className="fixed inset-0 z-[9998] flex items-center justify-center"
      style={{ background: 'rgba(0, 0, 0, 0.7)' }}
      onClick={handleBackdropClick}
    >
      <div
        className="rounded-lg shadow-2xl border relative"
        style={{
          width: '600px',
          background: 'var(--modal-bg)',
          borderColor: 'var(--card-border)',
          boxShadow: theme === 'cyber' ? '0 0 40px rgba(0, 255, 159, 0.3)' : '0 20px 60px rgba(0, 0, 0, 0.5)',
        }}
      >
        {/* Header with Close Button */}
        <div
          className="flex items-center justify-between p-6 border-b"
          style={{
            borderColor: 'var(--card-border)',
          }}
        >
          <h2 className="text-2xl font-bold" style={{ color: 'var(--text-primary)' }}>
            Change Theme
          </h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded flex items-center justify-center transition-all"
            style={{
              color: 'var(--text-secondary)',
              background: 'transparent',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'var(--table-row-hover)';
              e.currentTarget.style.color = 'var(--text-primary)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent';
              e.currentTarget.style.color = 'var(--text-secondary)';
            }}
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          <p className="mb-6" style={{ color: 'var(--text-secondary)' }}>
            Select a theme for the O.A.S.I.S. portal. Theme will be applied immediately.
          </p>

          <div className="grid grid-cols-2 gap-6">
            {/* Professional Theme Card */}
            <button
              onClick={() => handleThemeSelect('professional')}
              className="relative rounded-lg border-2 p-6 transition-all text-left"
              style={{
                borderColor: theme === 'professional' ? '#2563eb' : 'var(--card-border)',
                background: theme === 'professional' 
                  ? 'rgba(37, 99, 235, 0.1)' 
                  : 'var(--card-bg)',
                boxShadow: theme === 'professional' 
                  ? '0 0 20px rgba(37, 99, 235, 0.3)' 
                  : 'none',
              }}
            >
              {theme === 'professional' && (
                <div className="absolute top-3 right-3 w-6 h-6 rounded-full bg-[#2563eb] flex items-center justify-center text-white text-sm">
                  ✓
                </div>
              )}
              <div className="mb-4">
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-2xl">💼</span>
                  <h3 className="text-lg font-bold" style={{ color: 'var(--text-primary)' }}>
                    Professional
                  </h3>
                </div>
                <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                  Clean, modern interface with a professional aesthetic
                </p>
              </div>
              <div className="space-y-2">
                <div className="h-8 rounded" style={{ background: '#f3f4f6' }}></div>
                <div className="h-8 rounded" style={{ background: '#e5e7eb' }}></div>
                <div className="h-8 rounded" style={{ background: '#2563eb', opacity: 0.6 }}></div>
              </div>
            </button>

            {/* Cyber Theme Card */}
            <button
              onClick={() => handleThemeSelect('cyber')}
              className="relative rounded-lg border-2 p-6 transition-all text-left"
              style={{
                borderColor: theme === 'cyber' ? '#00ff9f' : 'var(--card-border)',
                background: theme === 'cyber' 
                  ? 'rgba(0, 255, 159, 0.1)' 
                  : 'var(--card-bg)',
                boxShadow: theme === 'cyber' 
                  ? '0 0 20px rgba(0, 255, 159, 0.3)' 
                  : 'none',
              }}
            >
              {theme === 'cyber' && (
                <div 
                  className="absolute top-3 right-3 w-6 h-6 rounded-full flex items-center justify-center text-sm font-bold"
                  style={{
                    background: '#00ff9f',
                    color: '#0a0e27',
                    boxShadow: '0 0 10px #00ff9f',
                  }}
                >
                  ✓
                </div>
              )}
              <div className="mb-4">
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-2xl">⚡</span>
                  <h3 className="text-lg font-bold" style={{ color: 'var(--text-primary)' }}>
                    Cyber
                  </h3>
                </div>
                <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                  Cyberpunk terminal aesthetic with neon glow effects
                </p>
              </div>
              <div className="space-y-2">
                <div className="h-8 rounded" style={{ background: '#0a0e27', border: '1px solid #00ff9f' }}></div>
                <div className="h-8 rounded" style={{ background: '#0a0e27', border: '1px solid #00d4ff' }}></div>
                <div className="h-8 rounded" style={{ background: '#00ff9f', opacity: 0.3 }}></div>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
