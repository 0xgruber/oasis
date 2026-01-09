'use client';

import { useEffect } from 'react';
import { useTheme } from '@/contexts/ThemeContext';

interface ToastProps {
  message: string;
  onClose: () => void;
  duration?: number;
  showPickaxe?: boolean;
}

export default function Toast({ message, onClose, duration = 3000, showPickaxe = false }: ToastProps) {
  const { theme } = useTheme();

  useEffect(() => {
    const timer = setTimeout(onClose, duration);
    return () => clearTimeout(timer);
  }, [duration, onClose]);

  return (
    <div className="fixed inset-0 flex items-center justify-center z-[9999] pointer-events-none">
      <div 
        className={`pointer-events-auto rounded-lg shadow-2xl p-6 border ${
          theme === 'cyber' 
            ? 'border-[var(--cyber-cyan)] bg-[rgba(10,14,39,0.95)]' 
            : 'border-slate-600 bg-slate-800'
        }`}
        style={{
          maxWidth: '400px',
          backdropFilter: 'blur(10px)',
        }}
      >
        {showPickaxe && (
          <div className="flex justify-center mb-4">
            <div className="pickaxe-man">
              <div className="pickaxe-man-body"></div>
              <div className="pickaxe"></div>
              <div className="rock"></div>
            </div>
          </div>
        )}
        <p 
          className="text-center text-lg font-medium"
          style={{ color: 'var(--text-primary)' }}
        >
          {message}
        </p>
      </div>
    </div>
  );
}
