'use client';

import { useState, useEffect } from 'react';
import { useTheme } from '@/contexts/ThemeContext';

interface AccountSettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  onShowToast: (message: string) => void;
}

export default function AccountSettingsModal({ isOpen, onClose, onShowToast }: AccountSettingsModalProps) {
  const { theme } = useTheme();
  const initialFormData = {
    firstName: 'Admin',
    lastName: 'User',
    email: 'admin@oasis.local',
    oldPassword: '',
    newPassword: '',
    confirmPassword: '',
  };
  
  const [formData, setFormData] = useState(initialFormData);

  // Mock user roles
  const userRoles = ['Administrator', 'Security Analyst'];
  const userPermissions = ['Read Logs', 'Write Alerts', 'Manage Users', 'System Configuration'];

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

  const hasChanges = () => {
    return formData.firstName !== initialFormData.firstName ||
           formData.lastName !== initialFormData.lastName ||
           formData.email !== initialFormData.email ||
           formData.oldPassword !== '' ||
           formData.newPassword !== '' ||
           formData.confirmPassword !== '';
  };

  const handleSave = () => {
    if (!hasChanges()) {
      onClose();
      return;
    }
    onShowToast('⚠️ Feature requires backend API - Coming in Phase 1C');
    onClose();
  };

  const handleChangePassword = () => {
    onShowToast('⚠️ Feature requires backend API - Coming in Phase 1C');
  };

  const handleEnableMFA = () => {
    onShowToast('⚠️ Feature requires backend API - Coming in Phase 1C');
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
          maxHeight: '90vh',
          overflowY: 'auto',
          background: 'var(--modal-bg)',
          borderColor: 'var(--card-border)',
          boxShadow: theme === 'cyber' ? '0 0 40px rgba(0, 255, 159, 0.3)' : '0 20px 60px rgba(0, 0, 0, 0.5)',
        }}
      >
        {/* Header with Close Button */}
        <div
          className="sticky top-0 z-10 flex items-center justify-between p-6 border-b"
          style={{
            background: 'var(--modal-bg)',
            borderColor: 'var(--card-border)',
          }}
        >
          <h2 className="text-2xl font-bold" style={{ color: 'var(--text-primary)' }}>
            Account Settings
          </h2>
          <button
            onClick={onClose}
            className="w-10 h-10 rounded flex items-center justify-center transition-all text-xl font-bold border"
            style={{
              color: 'var(--text-secondary)',
              background: 'transparent',
              borderColor: 'rgba(128, 128, 128, 0.5)',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'var(--table-row-hover)';
              e.currentTarget.style.color = 'var(--text-primary)';
              e.currentTarget.style.borderColor = 'var(--card-border)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent';
              e.currentTarget.style.color = 'var(--text-secondary)';
              e.currentTarget.style.borderColor = 'rgba(128, 128, 128, 0.5)';
            }}
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-8">
          {/* Profile Section */}
          <section>
            <h3 className="text-lg font-semibold mb-4" style={{ color: 'var(--text-primary)' }}>
              Profile Information
            </h3>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    First Name
                  </label>
                  <input
                    type="text"
                    value={formData.firstName}
                    onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                    className="w-full px-4 py-2 rounded border"
                    style={{
                      background: 'var(--input-bg)',
                      borderColor: 'var(--input-border)',
                      color: 'var(--text-primary)',
                    }}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                    Last Name
                  </label>
                  <input
                    type="text"
                    value={formData.lastName}
                    onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                    className="w-full px-4 py-2 rounded border"
                    style={{
                      background: 'var(--input-bg)',
                      borderColor: 'var(--input-border)',
                      color: 'var(--text-primary)',
                    }}
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                  Email Address
                </label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  className="w-full px-4 py-2 rounded border"
                  style={{
                    background: 'var(--input-bg)',
                    borderColor: 'var(--input-border)',
                    color: 'var(--text-primary)',
                  }}
                />
              </div>
            </div>
          </section>

          {/* Security Section */}
          <section>
            <h3 className="text-lg font-semibold mb-4" style={{ color: 'var(--text-primary)' }}>
              Security
            </h3>
            <div className="space-y-4">
              {/* Change Password */}
              <div>
                <p className="text-sm font-medium mb-3" style={{ color: 'var(--text-secondary)' }}>
                  Change Password
                </p>
                <div className="space-y-3">
                  <input
                    type="password"
                    placeholder="Current Password"
                    value={formData.oldPassword}
                    onChange={(e) => setFormData({ ...formData, oldPassword: e.target.value })}
                    className="w-full px-4 py-2 rounded border"
                    style={{
                      background: 'var(--input-bg)',
                      borderColor: 'var(--input-border)',
                      color: 'var(--text-primary)',
                    }}
                  />
                  <input
                    type="password"
                    placeholder="New Password"
                    value={formData.newPassword}
                    onChange={(e) => setFormData({ ...formData, newPassword: e.target.value })}
                    className="w-full px-4 py-2 rounded border"
                    style={{
                      background: 'var(--input-bg)',
                      borderColor: 'var(--input-border)',
                      color: 'var(--text-primary)',
                    }}
                  />
                  <input
                    type="password"
                    placeholder="Confirm New Password"
                    value={formData.confirmPassword}
                    onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                    className="w-full px-4 py-2 rounded border"
                    style={{
                      background: 'var(--input-bg)',
                      borderColor: 'var(--input-border)',
                      color: 'var(--text-primary)',
                    }}
                  />
                  <button
                    onClick={handleChangePassword}
                    className="px-4 py-2 rounded font-medium transition-all"
                    style={{
                      background: 'var(--primary)',
                      color: '#ffffff',
                      boxShadow: theme === 'cyber' ? '0 0 10px var(--primary)' : 'none',
                    }}
                  >
                    Change Password
                  </button>
                </div>
              </div>

              {/* MFA Section */}
              <div className="pt-4 border-t" style={{ borderColor: 'var(--card-border)' }}>
                <p className="text-sm font-medium mb-3" style={{ color: 'var(--text-secondary)' }}>
                  Multi-Factor Authentication
                </p>
                <button
                  onClick={handleEnableMFA}
                  className="px-4 py-2 rounded font-medium transition-all"
                  style={{
                    background: 'var(--primary)',
                    color: '#ffffff',
                    boxShadow: theme === 'cyber' ? '0 0 10px var(--primary)' : 'none',
                  }}
                >
                  Enable MFA
                </button>
              </div>
            </div>
          </section>

          {/* Roles & Permissions Section */}
          <section>
            <h3 className="text-lg font-semibold mb-4" style={{ color: 'var(--text-primary)' }}>
              Roles & Permissions
            </h3>
            <div className="space-y-4">
              <div>
                <p className="text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                  Roles
                </p>
                <div className="flex flex-wrap gap-2">
                  {userRoles.map((role) => (
                    <span
                      key={role}
                      className="px-3 py-1 rounded-full text-sm font-medium"
                      style={{
                        background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : 'rgba(37, 99, 235, 0.2)',
                        color: 'var(--primary)',
                        border: '1px solid var(--primary)',
                      }}
                    >
                      {role}
                    </span>
                  ))}
                </div>
              </div>
              <div>
                <p className="text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                  Permissions
                </p>
                <div className="flex flex-wrap gap-2">
                  {userPermissions.map((permission) => (
                    <span
                      key={permission}
                      className="px-3 py-1 rounded text-sm"
                      style={{
                        background: 'var(--table-header)',
                        color: 'var(--text-secondary)',
                        border: '1px solid var(--card-border)',
                      }}
                    >
                      {permission}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </section>
        </div>

        {/* Footer with Save Button */}
        <div
          className="sticky bottom-0 flex items-center justify-end p-6 border-t"
          style={{
            background: 'var(--modal-bg)',
            borderColor: 'var(--card-border)',
          }}
        >
          <button
            onClick={handleSave}
            className="px-6 py-2 rounded-lg font-medium transition-all"
            style={{
              background: 'var(--primary)',
              color: '#ffffff',
              boxShadow: theme === 'cyber' ? '0 0 15px var(--primary)' : '0 4px 12px rgba(37, 99, 235, 0.3)',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = theme === 'cyber' 
                ? '0 0 25px var(--primary)' 
                : '0 6px 16px rgba(37, 99, 235, 0.4)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = theme === 'cyber' 
                ? '0 0 15px var(--primary)' 
                : '0 4px 12px rgba(37, 99, 235, 0.3)';
            }}
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  );
}
