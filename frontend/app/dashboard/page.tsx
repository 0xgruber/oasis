'use client';

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

interface ServiceStatus {
  name: string;
  container: string;
  status: string;
  state: string;
  uptime_seconds: number;
  networks: string[];
}

export default function DashboardPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const [services, setServices] = useState<ServiceStatus[]>([]);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [servicesError, setServicesError] = useState<string | null>(null);

  // Format uptime seconds to human-readable string
  const formatUptime = (seconds: number): string => {
    if (seconds === 0) return '0s';
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (days > 0) return `${days}d ${hours}h`;
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  // Get status color based on health and state
  const getStatusColor = (status: string, state: string): string => {
    if (status === 'healthy' && state === 'running') {
      return theme === 'cyber' ? 'var(--cyber-green)' : '#4ade80'; // green
    }
    if (status === 'starting' || state === 'restarting') {
      return theme === 'cyber' ? 'var(--cyber-yellow)' : '#fbbf24'; // yellow
    }
    if (status === 'unhealthy' || state === 'exited' || state === 'stopped') {
      return '#ef4444'; // red
    }
    return '#94a3b8'; // gray (no health check)
  };

  // Get status text
  const getStatusText = (status: string, state: string): string => {
    if (status === 'healthy' && state === 'running') return 'operational';
    if (status === 'starting') return 'starting';
    if (state === 'restarting') return 'restarting';
    if (status === 'unhealthy') return 'unhealthy';
    if (state === 'exited' || state === 'stopped') return 'stopped';
    if (state === 'running') return 'running';
    return state;
  };

  // Fetch service status
  const fetchServiceStatus = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) {
        setServicesError('No authentication token found');
        setServicesLoading(false);
        return;
      }

      const response = await fetch('/api/services/status', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Authentication failed - please login again');
        }
        throw new Error(`Failed to fetch services (HTTP ${response.status})`);
      }

      const data = await response.json();
      setServices(data.services || []);
      setServicesError(null);
    } catch (error) {
      console.error('Failed to fetch service status:', error);
      setServicesError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setServicesLoading(false);
    }
  };

  // Poll service status every 30 seconds
  useEffect(() => {
    // Only fetch if user is authenticated
    if (!user) {
      setServicesLoading(false);
      setServicesError('Not authenticated');
      return;
    }

    fetchServiceStatus(); // Initial fetch
    
    const interval = setInterval(() => {
      fetchServiceStatus();
    }, 30000); // 30 seconds
    
    return () => clearInterval(interval);
  }, [user]); // Re-run when user changes

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
            { label: 'Total Logs', value: '0', icon: '📝', color: 'blue' },
            { label: 'Active Alerts', value: '0', icon: '🔔', color: 'red' },
            { label: 'Sources', value: '0', icon: '📡', color: 'green' },
            { label: 'Ingestion Rate', value: '0/s', icon: '⚡', color: 'yellow' },
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

        {/* System Status */}
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
            System Status
          </h2>
          
          {servicesLoading ? (
            <div className="text-center py-8" style={{ color: 'var(--text-secondary)' }}>
              Loading service status...
            </div>
          ) : servicesError ? (
            <div className="text-center py-8" style={{ color: '#ef4444' }}>
              Failed to load services: {servicesError}
            </div>
          ) : services.length === 0 ? (
            <div className="text-center py-8" style={{ color: 'var(--text-secondary)' }}>
              No services found
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {services.map((service) => {
                const statusColor = getStatusColor(service.status, service.state);
                const statusText = getStatusText(service.status, service.state);
                
                return (
                  <div
                    key={service.container}
                    className="flex flex-col p-4 rounded"
                    style={{
                      background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.05)' : '#334155',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.2)' : '1px solid #475569'
                    }}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <span 
                        className="font-medium"
                        style={{ color: 'var(--text-primary)' }}
                      >
                        {service.name}
                      </span>
                      <span 
                        className="text-xs px-2 py-1 rounded"
                        style={{ 
                          background: 'rgba(0, 0, 0, 0.3)',
                          color: 'var(--text-secondary)'
                        }}
                      >
                        {formatUptime(service.uptime_seconds)}
                      </span>
                    </div>
                    
                    <div className="flex items-center text-sm mb-2">
                      <span 
                        className="w-2 h-2 rounded-full mr-2"
                        style={{ 
                          background: statusColor,
                          boxShadow: theme === 'cyber' ? `0 0 10px ${statusColor}` : undefined
                        }}
                      ></span>
                      <span style={{ color: statusColor }}>
                        {statusText}
                      </span>
                    </div>
                    
                    {service.networks.length > 0 && (
                      <div className="flex flex-wrap gap-1 mt-2">
                        {(() => {
                          // Determine primary network (DMZ > Internal > Backend)
                          // Only show backend badge if it's the only network
                          const hasDMZ = service.networks.some(n => n.includes('dmz'));
                          const hasInternal = service.networks.some(n => n.includes('internal'));
                          const hasBackend = service.networks.some(n => n.includes('backend'));
                          
                          const badges = [];
                          
                          if (hasDMZ) {
                            badges.push({ label: 'DMZ', color: '#f59e0b' }); // amber
                          }
                          if (hasInternal) {
                            badges.push({ label: 'Internal', color: '#8b5cf6' }); // purple
                          }
                          // Only show backend if it's the only network
                          if (hasBackend && !hasDMZ && !hasInternal) {
                            badges.push({ label: 'Backend', color: '#6366f1' }); // indigo
                          }
                          
                          return badges.map((badge) => (
                            <span
                              key={badge.label}
                              className="text-xs px-2 py-1 rounded"
                              style={{
                                background: `${badge.color}33`,
                                color: badge.color,
                                border: `1px solid ${badge.color}66`
                              }}
                            >
                              {badge.label}
                            </span>
                          ));
                        })()}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </ProtectedRoute>
  );
}
