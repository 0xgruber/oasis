'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

export default function SystemSettingsPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const router = useRouter();
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Global message form
  const [message, setMessage] = useState('');
  const [enabled, setEnabled] = useState(false);
  const [messageUpdating, setMessageUpdating] = useState(false);
  const [messageSuccess, setMessageSuccess] = useState<string | null>(null);
  const [messageError, setMessageError] = useState<string | null>(null);

  // SMTP configuration form
  const [smtpEnabled, setSmtpEnabled] = useState(false);
  const [smtpHost, setSmtpHost] = useState('');
  const [smtpPort, setSmtpPort] = useState(587);
  const [smtpUseTls, setSmtpUseTls] = useState(true);
  const [smtpUseSsl, setSmtpUseSsl] = useState(false);
  const [smtpUsername, setSmtpUsername] = useState('');
  const [smtpPassword, setSmtpPassword] = useState('');
  const [smtpPasswordSet, setSmtpPasswordSet] = useState(false);
  const [smtpFromEmail, setSmtpFromEmail] = useState('');
  const [smtpFromName, setSmtpFromName] = useState('O.A.S.I.S. Security Platform');
  const [smtpUpdating, setSmtpUpdating] = useState(false);
  const [smtpSuccess, setSmtpSuccess] = useState<string | null>(null);
  const [smtpError, setSmtpError] = useState<string | null>(null);
  const [testEmailRecipient, setTestEmailRecipient] = useState('');
  const [testingEmail, setTestingEmail] = useState(false);
  const [testEmailSuccess, setTestEmailSuccess] = useState<string | null>(null);
  const [testEmailError, setTestEmailError] = useState<string | null>(null);

  // Fetch global message on mount
  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }

    const fetchSettings = async () => {
      try {
        const token = tokenUtils.getToken();
        if (!token) {
          throw new Error('No authentication token found');
        }

        // Fetch global message
        const messageResponse = await fetch('/api/system/message', {
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        if (!messageResponse.ok) {
          throw new Error(`Failed to load global message (HTTP ${messageResponse.status})`);
        }

        const messageData = await messageResponse.json();
        setMessage(messageData.message || '');
        setEnabled(messageData.enabled || false);

        // Fetch SMTP configuration
        const smtpResponse = await fetch('/api/system/smtp', {
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        if (!smtpResponse.ok) {
          throw new Error(`Failed to load SMTP configuration (HTTP ${smtpResponse.status})`);
        }

        const smtpData = await smtpResponse.json();
        setSmtpEnabled(smtpData.enabled || false);
        setSmtpHost(smtpData.host || '');
        setSmtpPort(smtpData.port || 587);
        setSmtpUseTls(smtpData.use_tls !== undefined ? smtpData.use_tls : true);
        setSmtpUseSsl(smtpData.use_ssl || false);
        setSmtpUsername(smtpData.username || '');
        setSmtpPasswordSet(smtpData.password_set || false);
        setSmtpFromEmail(smtpData.from_email || '');
        setSmtpFromName(smtpData.from_name || 'O.A.S.I.S. Security Platform');
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load settings');
      } finally {
        setLoading(false);
      }
    };

    fetchSettings();
  }, [user]);

  const handleUpdateMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessageError(null);
    setMessageSuccess(null);
    setMessageUpdating(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch('/api/system/message', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message,
          enabled,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to update global message (HTTP ${response.status})`);
      }

      setMessageSuccess('Global message updated successfully');
    } catch (err) {
      setMessageError(err instanceof Error ? err.message : 'Failed to update global message');
    } finally {
      setMessageUpdating(false);
    }
  };

  const handleUpdateSmtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setSmtpError(null);
    setSmtpSuccess(null);
    setSmtpUpdating(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const payload: any = {
        enabled: smtpEnabled,
        host: smtpHost,
        port: smtpPort,
        use_tls: smtpUseTls,
        use_ssl: smtpUseSsl,
        username: smtpUsername,
        from_email: smtpFromEmail,
        from_name: smtpFromName,
      };

      // Only include password if it's been changed
      if (smtpPassword) {
        payload.password = smtpPassword;
      }

      const response = await fetch('/api/system/smtp', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to update SMTP configuration (HTTP ${response.status})`);
      }

      const data = await response.json();
      setSmtpPasswordSet(data.password_set);
      setSmtpPassword(''); // Clear password field after successful update
      setSmtpSuccess('SMTP configuration updated successfully');
    } catch (err) {
      setSmtpError(err instanceof Error ? err.message : 'Failed to update SMTP configuration');
    } finally {
      setSmtpUpdating(false);
    }
  };

  const handleTestEmail = async () => {
    if (!testEmailRecipient) {
      setTestEmailError('Please enter a recipient email address');
      return;
    }

    setTestEmailError(null);
    setTestEmailSuccess(null);
    setTestingEmail(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch('/api/system/smtp/test', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          recipient: testEmailRecipient,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to send test email (HTTP ${response.status})`);
      }

      setTestEmailSuccess('Test email sent successfully! Check the recipient inbox.');
    } catch (err) {
      setTestEmailError(err instanceof Error ? err.message : 'Failed to send test email');
    } finally {
      setTestingEmail(false);
    }
  };

  const cardClass = theme === 'cyber' 
    ? 'terminal-card rounded-lg p-6' 
    : 'bg-slate-800 rounded-lg p-6 border border-slate-700';

  return (
    <ProtectedRoute>
      <div className="max-w-4xl mx-auto space-y-6">
        {/* Header */}
        <div className={cardClass}>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold" style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)' }}>
                System Settings
              </h1>
              <p className="mt-2" style={{ color: 'var(--text-secondary)' }}>
                Configure global system settings and messages
              </p>
            </div>
            <button
              onClick={() => router.push('/dashboard')}
              className="px-4 py-2 rounded transition-opacity hover:opacity-80"
              style={{
                background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.1)' : 'rgba(100, 116, 139, 0.3)',
                color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)',
                border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
              }}
            >
              ← Back to Dashboard
            </button>
          </div>
        </div>

        {loading && (
          <div className={cardClass}>
            <p style={{ color: 'var(--text-secondary)' }}>Loading settings...</p>
          </div>
        )}

        {error && (
          <div className={cardClass} style={{ borderColor: '#ef4444' }}>
            <p style={{ color: '#ef4444' }}>Error: {error}</p>
          </div>
        )}

        {!loading && !error && (
          <>
            {/* Global Message */}
            <div className={cardClass}>
              <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
                Global Message
              </h2>
              
              <div className="mb-4 p-4 rounded" style={{ background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)' }}>
                <p className="text-sm" style={{ color: '#60a5fa' }}>
                  <strong>ℹ️ Info:</strong> The global message will be displayed at the top of the dashboard for all users when enabled.
                </p>
              </div>
              
              <form onSubmit={handleUpdateMessage} className="space-y-4">
                <div className="flex items-center gap-3">
                  <input
                    type="checkbox"
                    id="message-enabled"
                    checked={enabled}
                    onChange={(e) => setEnabled(e.target.checked)}
                    className="w-5 h-5 rounded cursor-pointer"
                    style={{
                      accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    }}
                  />
                  <label htmlFor="message-enabled" className="text-sm font-medium cursor-pointer" style={{ color: 'var(--text-primary)' }}>
                    Display global message to all users
                  </label>
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Message Content
                  </label>
                  <textarea
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    rows={4}
                    placeholder="Enter a message to display to all users (e.g., system maintenance notice, important announcements)"
                    className="w-full px-4 py-2 rounded resize-none"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                  />
                  <p className="mt-1 text-xs" style={{ color: 'var(--text-secondary)' }}>
                    {message.length} characters
                  </p>
                </div>

                {/* Message Preview */}
                {message && (
                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                      Preview
                    </label>
                    <div className="p-4 rounded" style={{ background: 'rgba(251, 191, 36, 0.1)', border: '1px solid rgba(251, 191, 36, 0.3)' }}>
                      <div className="flex items-start gap-3">
                        <span style={{ color: '#fbbf24' }}>⚠️</span>
                        <p style={{ color: '#fbbf24' }}>{message}</p>
                      </div>
                    </div>
                  </div>
                )}

                {messageSuccess && (
                  <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                    <p style={{ color: '#22c55e' }}>{messageSuccess}</p>
                  </div>
                )}

                {messageError && (
                  <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                    <p style={{ color: '#ef4444' }}>{messageError}</p>
                  </div>
                )}

                <div className="flex gap-3">
                  <button
                    type="submit"
                    disabled={messageUpdating}
                    className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                    style={{
                      background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                      color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                    }}
                  >
                    {messageUpdating ? 'Saving...' : 'Save Changes'}
                  </button>
                  
                  {message !== '' && (
                    <button
                      type="button"
                      onClick={() => {
                        setMessage('');
                        setEnabled(false);
                      }}
                      className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80"
                      style={{
                        background: 'rgba(239, 68, 68, 0.1)',
                        color: '#ef4444',
                        border: '1px solid rgba(239, 68, 68, 0.3)',
                      }}
                    >
                      Clear Message
                    </button>
                  )}
                </div>
              </form>
            </div>

            {/* SMTP Configuration */}
            <div className={cardClass}>
              <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
                SMTP Configuration
              </h2>
              
              <div className="mb-4 p-4 rounded" style={{ background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)' }}>
                <p className="text-sm" style={{ color: '#60a5fa' }}>
                  <strong>ℹ️ Info:</strong> Configure SMTP settings to enable email notifications for user invitations and password resets. 
                  For Gmail, use an App Password instead of your regular password.
                </p>
              </div>
              
              <form onSubmit={handleUpdateSmtp} className="space-y-4">
                <div className="flex items-center gap-3">
                  <input
                    type="checkbox"
                    id="smtp-enabled"
                    checked={smtpEnabled}
                    onChange={(e) => setSmtpEnabled(e.target.checked)}
                    className="w-5 h-5 rounded cursor-pointer"
                    style={{
                      accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    }}
                  />
                  <label htmlFor="smtp-enabled" className="text-sm font-medium cursor-pointer" style={{ color: 'var(--text-primary)' }}>
                    Enable SMTP Email Delivery
                  </label>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                      SMTP Host
                    </label>
                    <input
                      type="text"
                      value={smtpHost}
                      onChange={(e) => setSmtpHost(e.target.value)}
                      placeholder="smtp.gmail.com"
                      className="w-full px-4 py-2 rounded"
                      style={{
                        background: 'rgba(0, 0, 0, 0.3)',
                        color: 'var(--text-primary)',
                        border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                      }}
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                      SMTP Port
                    </label>
                    <input
                      type="number"
                      value={smtpPort}
                      onChange={(e) => setSmtpPort(parseInt(e.target.value))}
                      placeholder="587"
                      className="w-full px-4 py-2 rounded"
                      style={{
                        background: 'rgba(0, 0, 0, 0.3)',
                        color: 'var(--text-primary)',
                        border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                      }}
                    />
                  </div>
                </div>

                <div className="flex gap-6">
                  <div className="flex items-center gap-3">
                    <input
                      type="checkbox"
                      id="smtp-tls"
                      checked={smtpUseTls}
                      onChange={(e) => setSmtpUseTls(e.target.checked)}
                      className="w-5 h-5 rounded cursor-pointer"
                      style={{
                        accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                      }}
                    />
                    <label htmlFor="smtp-tls" className="text-sm cursor-pointer" style={{ color: 'var(--text-secondary)' }}>
                      Use TLS (Port 587)
                    </label>
                  </div>

                  <div className="flex items-center gap-3">
                    <input
                      type="checkbox"
                      id="smtp-ssl"
                      checked={smtpUseSsl}
                      onChange={(e) => setSmtpUseSsl(e.target.checked)}
                      className="w-5 h-5 rounded cursor-pointer"
                      style={{
                        accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                      }}
                    />
                    <label htmlFor="smtp-ssl" className="text-sm cursor-pointer" style={{ color: 'var(--text-secondary)' }}>
                      Use SSL (Port 465)
                    </label>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    SMTP Username
                  </label>
                  <input
                    type="text"
                    value={smtpUsername}
                    onChange={(e) => setSmtpUsername(e.target.value)}
                    placeholder="your-email@example.com"
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    SMTP Password {smtpPasswordSet && <span className="text-xs">(currently set)</span>}
                  </label>
                  <input
                    type="password"
                    value={smtpPassword}
                    onChange={(e) => setSmtpPassword(e.target.value)}
                    placeholder={smtpPasswordSet ? "Leave blank to keep existing password" : "Enter SMTP password"}
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                  />
                  {smtpPasswordSet && (
                    <p className="mt-1 text-xs" style={{ color: 'var(--text-secondary)' }}>
                      Password is currently set. Enter a new password only if you want to change it.
                    </p>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                      From Email Address
                    </label>
                    <input
                      type="email"
                      value={smtpFromEmail}
                      onChange={(e) => setSmtpFromEmail(e.target.value)}
                      placeholder="noreply@example.com"
                      className="w-full px-4 py-2 rounded"
                      style={{
                        background: 'rgba(0, 0, 0, 0.3)',
                        color: 'var(--text-primary)',
                        border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                      }}
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                      From Name
                    </label>
                    <input
                      type="text"
                      value={smtpFromName}
                      onChange={(e) => setSmtpFromName(e.target.value)}
                      placeholder="O.A.S.I.S. Security Platform"
                      className="w-full px-4 py-2 rounded"
                      style={{
                        background: 'rgba(0, 0, 0, 0.3)',
                        color: 'var(--text-primary)',
                        border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                      }}
                    />
                  </div>
                </div>

                {smtpSuccess && (
                  <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                    <p style={{ color: '#22c55e' }}>{smtpSuccess}</p>
                  </div>
                )}

                {smtpError && (
                  <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                    <p style={{ color: '#ef4444' }}>{smtpError}</p>
                  </div>
                )}

                <div className="flex gap-3">
                  <button
                    type="submit"
                    disabled={smtpUpdating}
                    className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                    style={{
                      background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                      color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                    }}
                  >
                    {smtpUpdating ? 'Saving...' : 'Save SMTP Configuration'}
                  </button>
                </div>
              </form>

              {/* Test Email Section */}
              <div className="mt-6 pt-6 border-t" style={{ borderColor: 'rgba(100, 116, 139, 0.3)' }}>
                <h3 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
                  Test Email Configuration
                </h3>
                <p className="text-sm mb-4" style={{ color: 'var(--text-secondary)' }}>
                  Send a test email to verify your SMTP configuration is working correctly.
                </p>
                
                <div className="flex gap-3">
                  <input
                    type="email"
                    value={testEmailRecipient}
                    onChange={(e) => setTestEmailRecipient(e.target.value)}
                    placeholder="recipient@example.com"
                    className="flex-1 px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                  />
                  <button
                    type="button"
                    onClick={handleTestEmail}
                    disabled={testingEmail || !smtpEnabled}
                    className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                    style={{
                      background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : 'rgba(59, 130, 246, 0.2)',
                      color: theme === 'cyber' ? 'var(--cyber-green)' : '#60a5fa',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(59, 130, 246, 0.3)',
                    }}
                  >
                    {testingEmail ? 'Sending...' : 'Send Test Email'}
                  </button>
                </div>

                {testEmailSuccess && (
                  <div className="mt-3 p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                    <p style={{ color: '#22c55e' }}>{testEmailSuccess}</p>
                  </div>
                )}

                {testEmailError && (
                  <div className="mt-3 p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                    <p style={{ color: '#ef4444' }}>{testEmailError}</p>
                  </div>
                )}
              </div>
            </div>

            {/* Additional System Settings Placeholder */}
            <div className={cardClass}>
              <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
                Additional Settings
              </h2>
              
              <div className="space-y-3 opacity-50">
                <div className="flex justify-between items-center p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.2)', border: '1px solid rgba(100, 116, 139, 0.3)' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Session Timeout</span>
                  <span className="text-sm" style={{ color: 'var(--text-secondary)' }}>Coming Soon</span>
                </div>
                <div className="flex justify-between items-center p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.2)', border: '1px solid rgba(100, 116, 139, 0.3)' }}>
                  <span style={{ color: 'var(--text-secondary)' }}>Audit Log Retention</span>
                  <span className="text-sm" style={{ color: 'var(--text-secondary)' }}>Coming Soon</span>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </ProtectedRoute>
  );
}
