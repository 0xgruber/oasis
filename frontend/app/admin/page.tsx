'use client';

import { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';
import ProtectedRoute from '@/components/ProtectedRoute';

interface ServiceStatus {
  name: string;
  status: string;
  state: string;
}

/**
 * Admin Portal Home Page
 * 
 * Shows system-wide metrics and status
 */
export default function AdminHomePage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const [services, setServices] = useState<ServiceStatus[]>([]);
  const [servicesLoading, setServicesLoading] = useState(true);

  // Fetch service status
  const fetchServiceStatus = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) return;

      const response = await fetch('/api/services/status', {
        headers: { 'Authorization': `Bearer ${token}` },
      });

      if (response.ok) {
        const data = await response.json();
        setServices(data.services || []);
      }
    } catch (error) {
      console.error('Failed to fetch service status:', error);
    } finally {
      setServicesLoading(false);
    }
  };

  useEffect(() => {
    if (user) {
      fetchServiceStatus();
      const interval = setInterval(fetchServiceStatus, 30000);
      return () => clearInterval(interval);
    }
  }, [user]);

  const healthyServices = services.filter(s => s.status === 'healthy' && s.state === 'running').length;
  const totalServices = services.length;

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
            Platform Administration
          </h1>
          <p style={{ color: 'var(--text-secondary)' }}>
            Welcome, {user?.username}. You have full administrative access to the O.A.S.I.S. platform.
          </p>
        </div>

        {/* System Metrics */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[
            { label: 'Total Logs', value: '0', icon: '📝', color: theme === 'cyber' ? 'var(--primary)' : '#3b82f6' },
            { label: 'Sources', value: '0', icon: '📡', color: theme === 'cyber' ? 'var(--primary)' : '#10b981' },
            { label: 'Ingestion Rate', value: '0/s', icon: '⚡', color: theme === 'cyber' ? 'var(--primary)' : '#f59e0b' },
            { 
              label: 'System Status', 
              value: servicesLoading ? '...' : `${healthyServices}/${totalServices}`, 
              icon: '🖥️', 
              color: healthyServices === totalServices ? (theme === 'cyber' ? 'var(--primary)' : '#10b981') : '#ef4444'
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
              {theme === 'cyber' && (
                <div className="terminal-dots">
                  <div className="terminal-dot"></div>
                  <div className="terminal-dot"></div>
                  <div className="terminal-dot"></div>
                </div>
              )}
              <div className="flex items-center justify-between">
                <div>
                  <p 
                    className="text-sm mb-1"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    {stat.label}
                  </p>
                  <p 
                    className={`text-3xl font-bold ${theme === 'cyber' ? 'text-glow-subtle' : ''}`}
                    style={{ color: 'var(--text-primary)' }}
                  >
                    {stat.value}
                  </p>
                </div>
                <div 
                  className="text-4xl"
                  style={{ 
                    filter: theme === 'cyber' ? 'drop-shadow(0 0 10px currentColor)' : 'none',
                    color: stat.color
                  }}
                >
                  {stat.icon}
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Platform Info */}
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
            className={`text-lg font-semibold mb-4 ${theme === 'cyber' ? 'text-glow-subtle' : ''}`}
            style={{ color: 'var(--text-primary)' }}
          >
            Platform Information
          </h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Version</p>
              <p className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>Phase 2A</p>
            </div>
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Credential</p>
              <p className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>Platform Admin</p>
            </div>
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Architecture</p>
              <p className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>Three-Portal</p>
            </div>
            <div>
              <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>Services</p>
              <p 
                className="text-lg font-semibold" 
                style={{ color: healthyServices === totalServices ? (theme === 'cyber' ? 'var(--primary)' : '#10b981') : '#ef4444' }}
              >
                {servicesLoading ? 'Loading...' : 
                  healthyServices === totalServices ? 'Operational' : `${healthyServices}/${totalServices} Up`
                }
              </p>
            </div>
          </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
