'use client';

import ProtectedRoute from '@/components/ProtectedRoute';

export default function AnalyticsPage() {
  return (
    <ProtectedRoute>
      <div className="space-y-4">
        <h1 className="text-2xl font-bold text-white">Analytics</h1>
        <div className="p-4 bg-slate-800 border border-slate-700 rounded-lg">
          <p className="text-slate-300">
            Analytics is not implemented yet. This will include dashboards and aggregations over logs.
          </p>
        </div>
      </div>
    </ProtectedRoute>
  );
}
