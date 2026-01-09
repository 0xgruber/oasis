'use client';

import ProtectedRoute from '@/components/ProtectedRoute';

export default function AlertsPage() {
  return (
    <ProtectedRoute>
      <div className="space-y-4">
        <h1 className="text-2xl font-bold text-white">Alerts</h1>
        <div className="p-4 bg-slate-800 border border-slate-700 rounded-lg">
          <p className="text-slate-300">
            Alerts is not implemented yet. This will include detection rules, alert triage, and notifications.
          </p>
        </div>
      </div>
    </ProtectedRoute>
  );
}
