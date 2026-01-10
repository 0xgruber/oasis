'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

interface UserProfile {
  user_id: string;
  tenant_id: string | null;
  username: string;
  email: string;
  role: string;
  created_at: string | null;
  last_login_at: string | null;
}

export default function SettingsPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const router = useRouter();
  
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Profile update form
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [profileUpdating, setProfileUpdating] = useState(false);
  const [profileSuccess, setProfileSuccess] = useState<string | null>(null);
  const [profileError, setProfileError] = useState<string | null>(null);
  
  // Password change form
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordUpdating, setPasswordUpdating] = useState(false);
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);

  // Fetch profile on mount
  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }

    const fetchProfile = async () => {
      try {
        const token = tokenUtils.getToken();
        if (!token) {
          throw new Error('No authentication token found');
        }

        const response = await fetch('/api/account/profile', {
          headers: {
            'Authorization': `Bearer ${token}`,
          },
        });

        if (!response.ok) {
          throw new Error(`Failed to load profile (HTTP ${response.status})`);
        }

        const data = await response.json();
        setProfile(data);
        setEmail(data.email);
        setUsername(data.username);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load profile');
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, [user]);

  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setProfileError(null);
    setProfileSuccess(null);
    setProfileUpdating(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const updates: { email?: string; username?: string } = {};
      if (email !== profile?.email) updates.email = email;
      if (username !== profile?.username) updates.username = username;

      if (Object.keys(updates).length === 0) {
        setProfileError('No changes to save');
        return;
      }

      const response = await fetch('/api/account/profile', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(updates),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to update profile (HTTP ${response.status})`);
      }

      const data = await response.json();
      setProfile({ ...profile!, email: data.email, username: data.username });
      setProfileSuccess('Profile updated successfully');
    } catch (err) {
      setProfileError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setProfileUpdating(false);
    }
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError(null);
    setPasswordSuccess(null);

    // Validation
    if (newPassword.length < 8) {
      setPasswordError('New password must be at least 8 characters long');
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('New passwords do not match');
      return;
    }

    setPasswordUpdating(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch('/api/account/password', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          current_password: currentPassword,
          new_password: newPassword,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to change password (HTTP ${response.status})`);
      }

      setPasswordSuccess('Password changed successfully');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (err) {
      setPasswordError(err instanceof Error ? err.message : 'Failed to change password');
    } finally {
      setPasswordUpdating(false);
    }
  };

  const cardClass = theme === 'cyber' 
    ? 'terminal-card rounded-lg p-6' 
    : 'bg-slate-800 rounded-lg p-6 border border-slate-700';

  return (
    <ProtectedRoute>
      <div className="space-y-6">
        {/* Header */}
        <div className={cardClass}>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold" style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)' }}>
                Account Settings
              </h1>
              <p className="mt-2" style={{ color: 'var(--text-secondary)' }}>
                Manage your profile and security settings
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
            <p style={{ color: 'var(--text-secondary)' }}>Loading profile...</p>
          </div>
        )}

        {error && (
          <div className={cardClass} style={{ borderColor: '#ef4444' }}>
            <p style={{ color: '#ef4444' }}>Error: {error}</p>
          </div>
        )}

        {!loading && !error && profile && (
          <>
            {/* Profile Information */}
            <div className={cardClass}>
              <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
                Profile Information
              </h2>
              
              <form onSubmit={handleUpdateProfile} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Username
                  </label>
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Email Address
                  </label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Role
                  </label>
                  <input
                    type="text"
                    value={profile.role}
                    disabled
                    className="w-full px-4 py-2 rounded opacity-60"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-secondary)',
                      border: '1px solid rgba(100, 116, 139, 0.3)',
                    }}
                  />
                </div>

                {profileSuccess && (
                  <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                    <p style={{ color: '#22c55e' }}>{profileSuccess}</p>
                  </div>
                )}

                {profileError && (
                  <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                    <p style={{ color: '#ef4444' }}>{profileError}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={profileUpdating}
                  className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                  style={{
                    background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                  }}
                >
                  {profileUpdating ? 'Saving...' : 'Save Changes'}
                </button>
              </form>
            </div>

            {/* Change Password */}
            <div className={cardClass}>
              <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
                Change Password
              </h2>
              
              <form onSubmit={handleChangePassword} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Current Password
                  </label>
                  <input
                    type="password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    New Password
                  </label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                    required
                  />
                  <p className="mt-1 text-xs" style={{ color: 'var(--text-secondary)' }}>
                    Must be at least 8 characters long
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Confirm New Password
                  </label>
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="w-full px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                    required
                  />
                </div>

                {passwordSuccess && (
                  <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                    <p style={{ color: '#22c55e' }}>{passwordSuccess}</p>
                  </div>
                )}

                {passwordError && (
                  <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                    <p style={{ color: '#ef4444' }}>{passwordError}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={passwordUpdating}
                  className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                  style={{
                    background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                  }}
                >
                  {passwordUpdating ? 'Changing...' : 'Change Password'}
                </button>
              </form>
            </div>

            {/* Account Information (Read-only) */}
            <div className={cardClass}>
              <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
                Account Information
              </h2>
              
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span style={{ color: 'var(--text-secondary)' }}>User ID:</span>
                  <span className="font-mono text-sm" style={{ color: 'var(--text-primary)' }}>{profile.user_id}</span>
                </div>
                <div className="flex justify-between">
                  <span style={{ color: 'var(--text-secondary)' }}>Tenant ID:</span>
                  <span className="font-mono text-sm" style={{ color: 'var(--text-primary)' }}>{profile.tenant_id || 'N/A'}</span>
                </div>
                <div className="flex justify-between">
                  <span style={{ color: 'var(--text-secondary)' }}>Account Created:</span>
                  <span style={{ color: 'var(--text-primary)' }}>
                    {profile.created_at ? new Date(profile.created_at).toLocaleDateString() : 'N/A'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span style={{ color: 'var(--text-secondary)' }}>Last Login:</span>
                  <span style={{ color: 'var(--text-primary)' }}>
                    {profile.last_login_at ? new Date(profile.last_login_at).toLocaleString() : 'N/A'}
                  </span>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </ProtectedRoute>
  );
}
