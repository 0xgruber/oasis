'use client';

import { useState } from 'react';
import { useTheme } from '@/contexts/ThemeContext';

export default function ThemeSwitcher() {
  const { theme, toggleTheme } = useTheme();
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="text-sm text-slate-400 hover:text-white transition-colors"
        title="Theme Settings"
      >
        {theme === 'cyber' ? '⚡' : '💼'}
      </button>

      {isOpen && (
        <>
          {/* Backdrop */}
          <div
            className="fixed inset-0 z-10"
            onClick={() => setIsOpen(false)}
          />
          
          {/* Dropdown */}
          <div className="absolute bottom-full left-0 mb-2 w-48 bg-slate-800 border border-slate-700 rounded-lg shadow-lg z-20 overflow-hidden">
            <div className="p-2">
              <div className="text-xs font-semibold text-slate-400 px-2 py-1 mb-1">
                THEME
              </div>
              <button
                onClick={() => {
                  if (theme !== 'professional') toggleTheme();
                  setIsOpen(false);
                }}
                className={`w-full text-left px-3 py-2 rounded text-sm transition-colors ${
                  theme === 'professional'
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:bg-slate-700'
                }`}
              >
                <span className="mr-2">💼</span>
                Professional
              </button>
              <button
                onClick={() => {
                  if (theme !== 'cyber') toggleTheme();
                  setIsOpen(false);
                }}
                className={`w-full text-left px-3 py-2 rounded text-sm transition-colors mt-1 ${
                  theme === 'cyber'
                    ? 'bg-blue-600 text-white'
                    : 'text-slate-300 hover:bg-slate-700'
                }`}
              >
                <span className="mr-2">⚡</span>
                Cyber
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
