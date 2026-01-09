'use client';

import ProtectedRoute from '@/components/ProtectedRoute';

export default function SettingsPage() {
  return (
    <ProtectedRoute>
      <div className="space-y-4">
        <h1 className="text-2xl font-bold text-white">Settings</h1>
        <div className="p-4 bg-slate-800 border border-slate-700 rounded-lg">
          <p className="text-slate-300">
            Settings is not implemented yet. This will include API keys, tenants, and user management.
          </p>
        </div>
      </div>
    </ProtectedRoute>
  );
}
