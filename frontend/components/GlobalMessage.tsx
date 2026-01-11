'use client';

import { useEffect, useState } from 'react';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

// Simple hash function for message content
function hashMessage(message: string): string {
  let hash = 0;
  for (let i = 0; i < message.length; i++) {
    const char = message.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash).toString(36);
}

export default function GlobalMessage() {
  const { theme } = useTheme();
  const [message, setMessage] = useState<string | null>(null);
  const [enabled, setEnabled] = useState(false);
  const [messageHash, setMessageHash] = useState<string | null>(null);
  const [isDismissed, setIsDismissed] = useState(false);

  useEffect(() => {
    const fetchMessage = async () => {
      try {
        const token = tokenUtils.getToken();
        if (!token) return;

        const response = await fetch('/api/system/message', {
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        if (response.ok) {
          const data = await response.json();
          setMessage(data.message || null);
          setEnabled(data.enabled || false);
          
          // Calculate hash and check if dismissed in session
          if (data.message && data.enabled) {
            const hash = hashMessage(data.message);
            setMessageHash(hash);
            const dismissed = sessionStorage.getItem(`globalMessage_dismissed_${hash}`) === 'true';
            setIsDismissed(dismissed);
          }
        }
      } catch (err) {
        // Silently fail - message is optional
        console.error('Failed to fetch global message:', err);
      }
    };

    fetchMessage();
  }, []);

  const handleDismiss = () => {
    if (messageHash) {
      sessionStorage.setItem(`globalMessage_dismissed_${messageHash}`, 'true');
      setIsDismissed(true);
    }
  };

  // Don't show if disabled, dismissed, or no message
  if (!enabled || !message || isDismissed || message.trim() === '') {
    return null;
  }

  return (
    <div 
      className="mb-6 p-4 rounded-lg animate-fade-in"
      style={{ 
        background: 'rgba(251, 191, 36, 0.1)', 
        border: '1px solid rgba(251, 191, 36, 0.3)' 
      }}
    >
      <div className="flex items-start gap-3">
        <span style={{ color: '#fbbf24', fontSize: '20px' }}>⚠️</span>
        <div className="flex-1">
          <p style={{ color: '#fbbf24' }}>{message}</p>
        </div>
        <button
          onClick={handleDismiss}
          className="text-sm transition-opacity hover:opacity-80"
          style={{ color: '#fbbf24' }}
          aria-label="Dismiss message"
        >
          ✕
        </button>
      </div>
    </div>
  );
}
