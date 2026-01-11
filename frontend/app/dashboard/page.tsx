'use client';

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

export default function DashboardPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  
  // Metrics state
  const [metrics, setMetrics] = useState({
    totalLogs: 0,
    totalSources: 0,
    ingestionRate: 0,
  });
  const [metricsLoading, setMetricsLoading] = useState(true);

  // Fetch system metrics
  const fetchMetrics = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) return;

      const response = await fetch('/api/stats/metrics', {
        headers: { 'Authorization': `Bearer ${token}` },
      });

      if (response.ok) {
        const data = await response.json();
        setMetrics({
          totalLogs: data.total_logs || 0,
          totalSources: data.total_sources || 0,
          ingestionRate: data.ingestion_rate || 0,
        });
      }
    } catch (error) {
      console.error('Failed to fetch metrics:', error);
    } finally {
      setMetricsLoading(false);
    }
  };

  useEffect(() => {
    if (user) {
      fetchMetrics();
      const interval = setInterval(fetchMetrics, 30000);
      return () => clearInterval(interval);
    }
  }, [user]);

  const cardClass = theme === 'cyber' 
    ? 'terminal-card rounded-lg p-6' 
    : 'bg-slate-800 rounded-lg p-6 border border-slate-700';

  return (
    <ProtectedRoute>
      <div className="space-y-6">
        {/* Welcome Section */}
        <div 
          className={cardClass}
          style={{ 
            background: 'var(--card-bg)',
            border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
          }}
        >
          {theme === 'cyber' && (
            <div className="terminal-dots">
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
            </div>
          )}
          <h1 
            className={`text-2xl font-bold mb-2 ${theme === 'cyber' ? 'text-glow-subtle' : 'text-white'}`}
            style={{ color: 'var(--text-primary)' }}
          >
            Welcome back, {user?.username}!
          </h1>
          <p style={{ color: 'var(--text-secondary)' }}>
            Open-Source AI SIEM Intelligence System
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[
            { 
              label: 'Total Logs', 
              value: metricsLoading ? '...' : metrics.totalLogs.toLocaleString(), 
              icon: '📝', 
              color: 'blue' 
            },
            { 
              label: 'Active Alerts', 
              value: '0', 
              icon: '🔔', 
              color: 'red' 
            },
            { 
              label: 'Sources', 
              value: metricsLoading ? '...' : metrics.totalSources.toString(), 
              icon: '📡', 
              color: 'green' 
            },
            { 
              label: 'Ingestion Rate', 
              value: metricsLoading ? '...' : `${metrics.ingestionRate}/s`, 
              icon: '⚡', 
              color: 'yellow' 
            },
          ].map((stat) => (
            <div
              key={stat.label}
              className={cardClass}
              style={{ 
                background: 'var(--card-bg)',
                border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
              }}
            >
              <div className="flex items-center justify-between">
                <div>
                  <p 
                    className="text-sm mb-1"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    {stat.label}
                  </p>
                  <p 
                    className={`text-3xl font-bold ${theme === 'cyber' ? 'text-glow-subtle' : 'text-white'}`}
                    style={{ color: 'var(--text-primary)' }}
                  >
                    {stat.value}
                  </p>
                </div>
                <div className="text-4xl">{stat.icon}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Quick Actions */}
        <div 
          className={cardClass}
          style={{ 
            background: 'var(--card-bg)',
            border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
          }}
        >
          {theme === 'cyber' && (
            <div className="terminal-dots">
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
            </div>
          )}
          <h2 
            className={`text-lg font-semibold mb-4 ${theme === 'cyber' ? 'text-glow-subtle' : 'text-white'}`}
            style={{ color: 'var(--text-primary)' }}
          >
            Quick Actions
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {[
              { icon: '🔍', title: 'Search Logs', desc: 'Query your log data' },
              { icon: '📊', title: 'Create Dashboard', desc: 'Build custom views' },
              { icon: '🔔', title: 'Configure Alerts', desc: 'Set up notifications' },
            ].map((action) => (
              <button 
                key={action.title}
                className="p-4 rounded-lg text-left transition-colors"
                style={{
                  background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.05)' : '#334155',
                  border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid #475569'
                }}
                onMouseEnter={(e) => {
                  if (theme === 'cyber') {
                    e.currentTarget.style.borderColor = 'var(--cyber-cyan)';
                    e.currentTarget.style.boxShadow = '0 0 15px rgba(0, 212, 255, 0.3)';
                  } else {
                    e.currentTarget.style.background = '#475569';
                  }
                }}
                onMouseLeave={(e) => {
                  if (theme === 'cyber') {
                    e.currentTarget.style.borderColor = 'rgba(0, 255, 159, 0.3)';
                    e.currentTarget.style.boxShadow = 'none';
                  } else {
                    e.currentTarget.style.background = '#334155';
                  }
                }}
              >
                <div className="text-2xl mb-2">{action.icon}</div>
                <div 
                  className="font-medium"
                  style={{ color: 'var(--text-primary)' }}
                >
                  {action.title}
                </div>
                <div 
                  className="text-sm mt-1"
                  style={{ color: 'var(--text-secondary)' }}
                >
                  {action.desc}
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Recent Activity - Placeholder for Phase 2C */}
        <div 
          className={cardClass}
          style={{ 
            background: 'var(--card-bg)',
            border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
          }}
        >
          {theme === 'cyber' && (
            <div className="terminal-dots">
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
            </div>
          )}
          <h2 
            className={`text-lg font-semibold mb-4 ${theme === 'cyber' ? 'text-glow-subtle' : 'text-white'}`}
            style={{ color: 'var(--text-primary)' }}
          >
            Recent Activity
          </h2>
          <div className="text-center py-8" style={{ color: 'var(--text-secondary)' }}>
            <p className="mb-2">📊 Activity monitoring coming in Phase 2C</p>
            <p className="text-sm">View recent alerts, log ingestion stats, and security events</p>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
