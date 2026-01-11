'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

interface User {
  id: string;
  username: string;
  email: string;
  role: string;
  is_active: boolean;
  tenant_id: string | null;
  created_at: string;
  updated_at: string;
  last_login_at: string | null;
}

export default function UsersPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const router = useRouter();
  
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState<User[]>([]);
  const [error, setError] = useState<string | null>(null);
  
  // Filters
  const [showInactive, setShowInactive] = useState(false);
  const [roleFilter, setRoleFilter] = useState<string>('');
  
  // Modal states
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  
  // Form states for create user
  const [createUsername, setCreateUsername] = useState('');
  const [createEmail, setCreateEmail] = useState('');
  const [createPassword, setCreatePassword] = useState('');
  const [createRole, setCreateRole] = useState('viewer');
  const [createActive, setCreateActive] = useState(true);
  const [createLoading, setCreateLoading] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);
  const [createSuccess, setCreateSuccess] = useState<string | null>(null);
  
  // Form states for invite user
  const [inviteUsername, setInviteUsername] = useState('');
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState('viewer');
  const [inviteLoading, setInviteLoading] = useState(false);
  const [inviteError, setInviteError] = useState<string | null>(null);
  const [inviteSuccess, setInviteSuccess] = useState<string | null>(null);
  
  // Form states for edit user
  const [editEmail, setEditEmail] = useState('');
  const [editRole, setEditRole] = useState('');
  const [editActive, setEditActive] = useState(true);
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);
  const [editSuccess, setEditSuccess] = useState<string | null>(null);

  const roles = ['super_admin', 'admin', 'analyst', 'viewer'];

  const fetchUsers = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      let url = '/api/users?limit=100&offset=0';
      if (roleFilter) {
        url += `&role=${roleFilter}`;
      }
      if (showInactive !== null) {
        url += `&is_active=${!showInactive}`;
      }

      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to load users (HTTP ${response.status})`);
      }

      const data = await response.json();
      setUsers(data.users || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }

    fetchUsers();
  }, [user, showInactive, roleFilter]);

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    setCreateError(null);
    setCreateSuccess(null);
    setCreateLoading(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch('/api/users', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          username: createUsername,
          email: createEmail,
          password: createPassword,
          role: createRole,
          is_active: createActive,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to create user (HTTP ${response.status})`);
      }

      setCreateSuccess('User created successfully');
      setCreateUsername('');
      setCreateEmail('');
      setCreatePassword('');
      setCreateRole('viewer');
      setCreateActive(true);
      
      // Refresh user list
      await fetchUsers();
      
      // Close modal after 1 second
      setTimeout(() => {
        setShowCreateModal(false);
        setCreateSuccess(null);
      }, 1000);
    } catch (err) {
      setCreateError(err instanceof Error ? err.message : 'Failed to create user');
    } finally {
      setCreateLoading(false);
    }
  };

  const handleInviteUser = async (e: React.FormEvent) => {
    e.preventDefault();
    setInviteError(null);
    setInviteSuccess(null);
    setInviteLoading(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch('/api/users/invite', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          username: inviteUsername,
          email: inviteEmail,
          role: inviteRole,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to invite user (HTTP ${response.status})`);
      }

      setInviteSuccess('User invited successfully. Invitation email sent.');
      setInviteUsername('');
      setInviteEmail('');
      setInviteRole('viewer');
      
      // Refresh user list
      await fetchUsers();
      
      // Close modal after 2 seconds
      setTimeout(() => {
        setShowInviteModal(false);
        setInviteSuccess(null);
      }, 2000);
    } catch (err) {
      setInviteError(err instanceof Error ? err.message : 'Failed to invite user');
    } finally {
      setInviteLoading(false);
    }
  };

  const handleEditUser = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser) return;

    setEditError(null);
    setEditSuccess(null);
    setEditLoading(true);

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch(`/api/users/${selectedUser.id}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: editEmail,
          role: editRole,
          is_active: editActive,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to update user (HTTP ${response.status})`);
      }

      setEditSuccess('User updated successfully');
      
      // Refresh user list
      await fetchUsers();
      
      // Close modal after 1 second
      setTimeout(() => {
        setShowEditModal(false);
        setEditSuccess(null);
        setSelectedUser(null);
      }, 1000);
    } catch (err) {
      setEditError(err instanceof Error ? err.message : 'Failed to update user');
    } finally {
      setEditLoading(false);
    }
  };

  const handleDeleteUser = async (userId: string, username: string) => {
    if (!confirm(`Are you sure you want to delete user "${username}"? This will deactivate their account.`)) {
      return;
    }

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch(`/api/users/${userId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to delete user (HTTP ${response.status})`);
      }

      // Refresh user list
      await fetchUsers();
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to delete user');
    }
  };

  const handleResetPassword = async (userId: string, username: string) => {
    if (!confirm(`Send password reset email to user "${username}"?`)) {
      return;
    }

    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      const response = await fetch(`/api/users/${userId}/reset-password`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || `Failed to reset password (HTTP ${response.status})`);
      }

      const result = await response.json();
      alert(result.message);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to reset password');
    }
  };

  const openEditModal = (user: User) => {
    setSelectedUser(user);
    setEditEmail(user.email);
    setEditRole(user.role);
    setEditActive(user.is_active);
    setEditError(null);
    setEditSuccess(null);
    setShowEditModal(true);
  };

  const cardClass = theme === 'cyber' 
    ? 'terminal-card rounded-lg p-6' 
    : 'bg-slate-800 rounded-lg p-6 border border-slate-700';

  const buttonClass = (variant: 'primary' | 'secondary' | 'danger' = 'primary') => {
    if (variant === 'danger') {
      return 'px-4 py-2 rounded transition-opacity hover:opacity-80';
    }
    return 'px-4 py-2 rounded transition-opacity hover:opacity-80';
  };

  return (
    <ProtectedRoute>
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className={cardClass}>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold" style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)' }}>
                User Management
              </h1>
              <p className="mt-2" style={{ color: 'var(--text-secondary)' }}>
                Manage user accounts, roles, and permissions
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
            <p style={{ color: 'var(--text-secondary)' }}>Loading users...</p>
          </div>
        )}

        {error && (
          <div className={cardClass} style={{ borderColor: '#ef4444' }}>
            <p style={{ color: '#ef4444' }}>Error: {error}</p>
          </div>
        )}

        {!loading && !error && (
          <>
            {/* Actions and Filters */}
            <div className={cardClass}>
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div className="flex gap-3">
                  <button
                    onClick={() => setShowCreateModal(true)}
                    className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80"
                    style={{
                      background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                      color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                    }}
                  >
                    + Create User
                  </button>
                  <button
                    onClick={() => setShowInviteModal(true)}
                    className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80"
                    style={{
                      background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : 'rgba(59, 130, 246, 0.2)',
                      color: theme === 'cyber' ? 'var(--cyber-green)' : '#60a5fa',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(59, 130, 246, 0.3)',
                    }}
                  >
                    📧 Invite User
                  </button>
                </div>

                <div className="flex gap-3 items-center">
                  <select
                    value={roleFilter}
                    onChange={(e) => setRoleFilter(e.target.value)}
                    className="px-4 py-2 rounded"
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      color: 'var(--text-primary)',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                    }}
                  >
                    <option value="">All Roles</option>
                    {roles.map(role => (
                      <option key={role} value={role}>{role}</option>
                    ))}
                  </select>

                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={showInactive}
                      onChange={(e) => setShowInactive(e.target.checked)}
                      className="w-5 h-5 rounded cursor-pointer"
                      style={{
                        accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                      }}
                    />
                    <span className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                      Show Inactive
                    </span>
                  </label>
                </div>
              </div>
            </div>

            {/* Users Table */}
            <div className={cardClass}>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr style={{ borderBottom: '1px solid rgba(100, 116, 139, 0.3)' }}>
                      <th className="text-left py-3 px-4" style={{ color: 'var(--text-primary)' }}>Username</th>
                      <th className="text-left py-3 px-4" style={{ color: 'var(--text-primary)' }}>Email</th>
                      <th className="text-left py-3 px-4" style={{ color: 'var(--text-primary)' }}>Role</th>
                      <th className="text-left py-3 px-4" style={{ color: 'var(--text-primary)' }}>Status</th>
                      <th className="text-left py-3 px-4" style={{ color: 'var(--text-primary)' }}>Last Login</th>
                      <th className="text-right py-3 px-4" style={{ color: 'var(--text-primary)' }}>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.map((u) => (
                      <tr key={u.id} style={{ borderBottom: '1px solid rgba(100, 116, 139, 0.2)' }}>
                        <td className="py-3 px-4" style={{ color: 'var(--text-primary)' }}>
                          {u.username}
                          {u.id === user?.user_id && <span className="ml-2 text-xs" style={{ color: 'var(--text-secondary)' }}>(You)</span>}
                        </td>
                        <td className="py-3 px-4" style={{ color: 'var(--text-secondary)' }}>{u.email}</td>
                        <td className="py-3 px-4">
                          <span
                            className="px-2 py-1 rounded text-xs font-medium"
                            style={{
                              background: u.role === 'super_admin' ? 'rgba(168, 85, 247, 0.2)' :
                                         u.role === 'admin' ? 'rgba(59, 130, 246, 0.2)' :
                                         u.role === 'analyst' ? 'rgba(34, 197, 94, 0.2)' :
                                         'rgba(100, 116, 139, 0.2)',
                              color: u.role === 'super_admin' ? '#c084fc' :
                                     u.role === 'admin' ? '#60a5fa' :
                                     u.role === 'analyst' ? '#4ade80' :
                                     '#94a3b8',
                            }}
                          >
                            {u.role}
                          </span>
                        </td>
                        <td className="py-3 px-4">
                          <span
                            className="px-2 py-1 rounded text-xs font-medium"
                            style={{
                              background: u.is_active ? 'rgba(34, 197, 94, 0.2)' : 'rgba(239, 68, 68, 0.2)',
                              color: u.is_active ? '#4ade80' : '#f87171',
                            }}
                          >
                            {u.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="py-3 px-4" style={{ color: 'var(--text-secondary)' }}>
                          {u.last_login_at ? new Date(u.last_login_at).toLocaleDateString() : 'Never'}
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex gap-2 justify-end">
                            <button
                              onClick={() => openEditModal(u)}
                              className="px-3 py-1 rounded text-sm transition-opacity hover:opacity-80"
                              style={{
                                background: 'rgba(59, 130, 246, 0.2)',
                                color: '#60a5fa',
                                border: '1px solid rgba(59, 130, 246, 0.3)',
                              }}
                            >
                              Edit
                            </button>
                            <button
                              onClick={() => handleResetPassword(u.id, u.username)}
                              className="px-3 py-1 rounded text-sm transition-opacity hover:opacity-80"
                              style={{
                                background: 'rgba(251, 191, 36, 0.2)',
                                color: '#fbbf24',
                                border: '1px solid rgba(251, 191, 36, 0.3)',
                              }}
                            >
                              Reset PW
                            </button>
                            {u.id !== user?.user_id && (
                              <button
                                onClick={() => handleDeleteUser(u.id, u.username)}
                                className="px-3 py-1 rounded text-sm transition-opacity hover:opacity-80"
                                style={{
                                  background: 'rgba(239, 68, 68, 0.2)',
                                  color: '#f87171',
                                  border: '1px solid rgba(239, 68, 68, 0.3)',
                                }}
                              >
                                Delete
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>

                {users.length === 0 && (
                  <div className="text-center py-8" style={{ color: 'var(--text-secondary)' }}>
                    No users found
                  </div>
                )}
              </div>
            </div>
          </>
        )}
      </div>

      {/* Create User Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onClick={() => setShowCreateModal(false)}>
          <div className={cardClass + " max-w-md w-full m-4"} onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>Create User</h2>
            
            <form onSubmit={handleCreateUser} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Username</label>
                <input
                  type="text"
                  value={createUsername}
                  onChange={(e) => setCreateUsername(e.target.value)}
                  required
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Email</label>
                <input
                  type="email"
                  value={createEmail}
                  onChange={(e) => setCreateEmail(e.target.value)}
                  required
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Password</label>
                <input
                  type="password"
                  value={createPassword}
                  onChange={(e) => setCreatePassword(e.target.value)}
                  required
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Role</label>
                <select
                  value={createRole}
                  onChange={(e) => setCreateRole(e.target.value)}
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                >
                  {roles.map(role => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </div>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="create-active"
                  checked={createActive}
                  onChange={(e) => setCreateActive(e.target.checked)}
                  className="w-5 h-5 rounded cursor-pointer"
                  style={{
                    accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                  }}
                />
                <label htmlFor="create-active" className="text-sm cursor-pointer" style={{ color: 'var(--text-secondary)' }}>
                  Active
                </label>
              </div>

              {createSuccess && (
                <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                  <p style={{ color: '#22c55e' }}>{createSuccess}</p>
                </div>
              )}

              {createError && (
                <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                  <p style={{ color: '#ef4444' }}>{createError}</p>
                </div>
              )}

              <div className="flex gap-3">
                <button
                  type="submit"
                  disabled={createLoading}
                  className="flex-1 px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                  style={{
                    background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                  }}
                >
                  {createLoading ? 'Creating...' : 'Create User'}
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80"
                  style={{
                    background: 'rgba(100, 116, 139, 0.2)',
                    color: 'var(--text-secondary)',
                    border: '1px solid rgba(100, 116, 139, 0.3)',
                  }}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Invite User Modal */}
      {showInviteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onClick={() => setShowInviteModal(false)}>
          <div className={cardClass + " max-w-md w-full m-4"} onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>Invite User</h2>
            
            <div className="mb-4 p-4 rounded" style={{ background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)' }}>
              <p className="text-sm" style={{ color: '#60a5fa' }}>
                An invitation email will be sent with instructions to set up their account.
              </p>
            </div>

            <form onSubmit={handleInviteUser} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Username</label>
                <input
                  type="text"
                  value={inviteUsername}
                  onChange={(e) => setInviteUsername(e.target.value)}
                  required
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Email</label>
                <input
                  type="email"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  required
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Role</label>
                <select
                  value={inviteRole}
                  onChange={(e) => setInviteRole(e.target.value)}
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                >
                  {roles.map(role => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </div>

              {inviteSuccess && (
                <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                  <p style={{ color: '#22c55e' }}>{inviteSuccess}</p>
                </div>
              )}

              {inviteError && (
                <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                  <p style={{ color: '#ef4444' }}>{inviteError}</p>
                </div>
              )}

              <div className="flex gap-3">
                <button
                  type="submit"
                  disabled={inviteLoading}
                  className="flex-1 px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                  style={{
                    background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                  }}
                >
                  {inviteLoading ? 'Sending...' : 'Send Invitation'}
                </button>
                <button
                  type="button"
                  onClick={() => setShowInviteModal(false)}
                  className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80"
                  style={{
                    background: 'rgba(100, 116, 139, 0.2)',
                    color: 'var(--text-secondary)',
                    border: '1px solid rgba(100, 116, 139, 0.3)',
                  }}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit User Modal */}
      {showEditModal && selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" onClick={() => setShowEditModal(false)}>
          <div className={cardClass + " max-w-md w-full m-4"} onClick={(e) => e.stopPropagation()}>
            <h2 className="text-xl font-bold mb-4" style={{ color: 'var(--text-primary)' }}>
              Edit User: {selectedUser.username}
            </h2>
            
            <form onSubmit={handleEditUser} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Email</label>
                <input
                  type="email"
                  value={editEmail}
                  onChange={(e) => setEditEmail(e.target.value)}
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>Role</label>
                <select
                  value={editRole}
                  onChange={(e) => setEditRole(e.target.value)}
                  className="w-full px-4 py-2 rounded"
                  style={{
                    background: 'rgba(0, 0, 0, 0.3)',
                    color: 'var(--text-primary)',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid rgba(100, 116, 139, 0.5)',
                  }}
                >
                  {roles.map(role => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </div>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="edit-active"
                  checked={editActive}
                  onChange={(e) => setEditActive(e.target.checked)}
                  className="w-5 h-5 rounded cursor-pointer"
                  style={{
                    accentColor: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                  }}
                />
                <label htmlFor="edit-active" className="text-sm cursor-pointer" style={{ color: 'var(--text-secondary)' }}>
                  Active
                </label>
              </div>

              {editSuccess && (
                <div className="p-3 rounded" style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                  <p style={{ color: '#22c55e' }}>{editSuccess}</p>
                </div>
              )}

              {editError && (
                <div className="p-3 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                  <p style={{ color: '#ef4444' }}>{editError}</p>
                </div>
              )}

              <div className="flex gap-3">
                <button
                  type="submit"
                  disabled={editLoading}
                  className="flex-1 px-6 py-2 rounded font-medium transition-opacity hover:opacity-80 disabled:opacity-50"
                  style={{
                    background: theme === 'cyber' ? 'var(--cyber-green)' : '#3b82f6',
                    color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
                  }}
                >
                  {editLoading ? 'Saving...' : 'Save Changes'}
                </button>
                <button
                  type="button"
                  onClick={() => setShowEditModal(false)}
                  className="px-6 py-2 rounded font-medium transition-opacity hover:opacity-80"
                  style={{
                    background: 'rgba(100, 116, 139, 0.2)',
                    color: 'var(--text-secondary)',
                    border: '1px solid rgba(100, 116, 139, 0.3)',
                  }}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </ProtectedRoute>
  );
}
