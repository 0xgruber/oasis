'use client';

import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';

export default function DashboardPage() {
  const { user } = useAuth();

  return (
    <ProtectedRoute>
      <div className="space-y-6">
        {/* Welcome Section */}
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <h1 className="text-2xl font-bold text-white mb-2">
            Welcome back, {user?.username}!
          </h1>
          <p className="text-slate-400">
            Open-Source AI SIEM Intelligence System
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[
            { label: 'Total Logs', value: '0', icon: '📝', color: 'blue' },
            { label: 'Active Alerts', value: '0', icon: '🔔', color: 'red' },
            { label: 'Sources', value: '0', icon: '📡', color: 'green' },
            { label: 'Ingestion Rate', value: '0/s', icon: '⚡', color: 'yellow' },
          ].map((stat) => (
            <div
              key={stat.label}
              className="bg-slate-800 rounded-lg p-6 border border-slate-700"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-slate-400 mb-1">{stat.label}</p>
                  <p className="text-3xl font-bold text-white">{stat.value}</p>
                </div>
                <div className="text-4xl">{stat.icon}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Quick Actions */}
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <h2 className="text-lg font-semibold text-white mb-4">Quick Actions</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button className="p-4 bg-slate-700 hover:bg-slate-600 rounded-lg text-left transition-colors border border-slate-600">
              <div className="text-2xl mb-2">🔍</div>
              <div className="text-white font-medium">Search Logs</div>
              <div className="text-sm text-slate-400 mt-1">Query your log data</div>
            </button>
            <button className="p-4 bg-slate-700 hover:bg-slate-600 rounded-lg text-left transition-colors border border-slate-600">
              <div className="text-2xl mb-2">📊</div>
              <div className="text-white font-medium">Create Dashboard</div>
              <div className="text-sm text-slate-400 mt-1">Build custom views</div>
            </button>
            <button className="p-4 bg-slate-700 hover:bg-slate-600 rounded-lg text-left transition-colors border border-slate-600">
              <div className="text-2xl mb-2">🔔</div>
              <div className="text-white font-medium">Configure Alerts</div>
              <div className="text-sm text-slate-400 mt-1">Set up notifications</div>
            </button>
          </div>
        </div>

        {/* System Status */}
        <div className="bg-slate-800 rounded-lg p-6 border border-slate-700">
          <h2 className="text-lg font-semibold text-white mb-4">System Status</h2>
          <div className="space-y-3">
            {[
              { name: 'Gateway Service', status: 'operational' },
              { name: 'Ingestion Service', status: 'operational' },
              { name: 'API Service', status: 'operational' },
              { name: 'Database', status: 'operational' },
            ].map((service) => (
              <div
                key={service.name}
                className="flex items-center justify-between p-3 bg-slate-700 rounded border border-slate-600"
              >
                <span className="text-slate-300">{service.name}</span>
                <span className="flex items-center text-green-400">
                  <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                  {service.status}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
