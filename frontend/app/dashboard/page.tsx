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
  description?: string;
  network_details?: Array<{
    name: string;
    ip_address: string;
    gateway: string;
  }>;
  port_bindings?: Array<{
    internal: string;
    external: string | null;
  }>;
  mounts?: Array<{
    type: string;
    source: string;
    destination: string;
    mode: string;
  }>;
  image?: string;
  env_vars?: string[];
}

export default function DashboardPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  const [services, setServices] = useState<ServiceStatus[]>([]);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [servicesError, setServicesError] = useState<string | null>(null);
  const [selectedService, setSelectedService] = useState<ServiceStatus | null>(null);
  const [showModal, setShowModal] = useState(false);

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

  // Handle ESC key to close modal
  useEffect(() => {
    const handleEscKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && showModal) {
        setShowModal(false);
      }
    };

    document.addEventListener('keydown', handleEscKey);
    return () => document.removeEventListener('keydown', handleEscKey);
  }, [showModal]);

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
            <div className="space-y-6">
              {/* Group services by network zone */}
              {(() => {
                // Categorize services by primary network
                const dmzServices = services.filter(s => s.networks.some(n => n.includes('dmz')));
                const internalServices = services.filter(s => 
                  !s.networks.some(n => n.includes('dmz')) && 
                  s.networks.some(n => n.includes('internal'))
                );
                const backendServices = services.filter(s => 
                  !s.networks.some(n => n.includes('dmz')) && 
                  !s.networks.some(n => n.includes('internal'))
                );

                const renderServiceCards = (serviceList: ServiceStatus[]) => (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {serviceList.map((service) => {
                      const statusColor = getStatusColor(service.status, service.state);
                      const statusText = getStatusText(service.status, service.state);
                      
                      return (
                        <div
                          key={service.container}
                          className="flex flex-col p-4 rounded cursor-pointer hover:opacity-80 transition-opacity"
                          style={{
                            background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.05)' : '#334155',
                            border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.2)' : '1px solid #475569'
                          }}
                          onClick={() => {
                            setSelectedService(service);
                            setShowModal(true);
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
                );

                return (
                  <>
                    {/* DMZ Zone */}
                    {dmzServices.length > 0 && (
                      <div>
                        <h3 
                          className="text-md font-semibold mb-3 flex items-center"
                          style={{ color: '#f59e0b' }}
                        >
                          <span className="mr-2">🌐</span> DMZ Zone
                        </h3>
                        {renderServiceCards(dmzServices)}
                      </div>
                    )}

                    {/* Internal Zone */}
                    {internalServices.length > 0 && (
                      <div>
                        <h3 
                          className="text-md font-semibold mb-3 flex items-center"
                          style={{ color: '#8b5cf6' }}
                        >
                          <span className="mr-2">🏢</span> Internal Zone
                        </h3>
                        {renderServiceCards(internalServices)}
                      </div>
                    )}

                    {/* Backend Zone */}
                    {backendServices.length > 0 && (
                      <div>
                        <h3 
                          className="text-md font-semibold mb-3 flex items-center"
                          style={{ color: '#6366f1' }}
                        >
                          <span className="mr-2">⚙️</span> Backend Zone
                        </h3>
                        {renderServiceCards(backendServices)}
                      </div>
                    )}
                  </>
                );
              })()}
            </div>
          )}
        </div>
      </div>

      {/* Service Details Modal */}
      {showModal && selectedService && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
          onClick={() => setShowModal(false)}
        >
          <div 
            className="rounded-lg p-6 max-w-4xl max-h-[85vh] overflow-y-auto w-full"
            style={{
              background: theme === 'cyber' ? 'rgba(15, 23, 42, 0.98)' : '#1e293b',
              border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid #475569'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between mb-4 pb-4 border-b" style={{ borderColor: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : '#475569' }}>
              <h3 className="text-2xl font-bold" style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)' }}>
                {selectedService.name}
              </h3>
              <button 
                onClick={() => setShowModal(false)}
                className="text-2xl hover:opacity-70 transition-opacity"
                style={{ color: 'var(--text-secondary)' }}
              >
                ✕
              </button>
            </div>

            {/* Description */}
            {selectedService.description && (
              <div className="mb-6">
                <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                  {selectedService.description}
                </p>
              </div>
            )}

            {/* Status Section */}
            <div className="mb-6">
              <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>Status</h4>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                  <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Health</div>
                  <div className="flex items-center">
                    <span 
                      className="w-2 h-2 rounded-full mr-2"
                      style={{ background: getStatusColor(selectedService.status, selectedService.state) }}
                    ></span>
                    <span className="font-medium" style={{ color: getStatusColor(selectedService.status, selectedService.state) }}>
                      {getStatusText(selectedService.status, selectedService.state)}
                    </span>
                  </div>
                </div>
                <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                  <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>State</div>
                  <div className="font-medium" style={{ color: 'var(--text-primary)' }}>{selectedService.state}</div>
                </div>
                <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                  <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Uptime</div>
                  <div className="font-medium" style={{ color: 'var(--text-primary)' }}>{formatUptime(selectedService.uptime_seconds)}</div>
                </div>
              </div>
            </div>

            {/* Network Information */}
            {selectedService.network_details && selectedService.network_details.length > 0 && (
              <div className="mb-6">
                <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>Network</h4>
                <div className="space-y-2">
                  {selectedService.network_details.map((net) => (
                    <div key={net.name} className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                      <div className="font-medium mb-1" style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)' }}>
                        {net.name.replace('oasis_', '')}
                      </div>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div>
                          <span style={{ color: 'var(--text-secondary)' }}>IP: </span>
                          <span style={{ color: 'var(--text-primary)' }}>{net.ip_address || 'N/A'}</span>
                        </div>
                        <div>
                          <span style={{ color: 'var(--text-secondary)' }}>Gateway: </span>
                          <span style={{ color: 'var(--text-primary)' }}>{net.gateway || 'N/A'}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Port Mappings */}
            {selectedService.port_bindings && selectedService.port_bindings.length > 0 && (
              <div className="mb-6">
                <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>Ports</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {selectedService.port_bindings.map((port, idx) => (
                    <div key={idx} className="p-3 rounded text-sm" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                      {port.external ? (
                        <span style={{ color: 'var(--text-primary)' }}>
                          <span style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : '#4ade80' }}>{port.external}</span>
                          {' → '}
                          <span>{port.internal}</span>
                        </span>
                      ) : (
                        <span style={{ color: 'var(--text-secondary)' }}>{port.internal} (exposed)</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Volume Mounts */}
            {selectedService.mounts && selectedService.mounts.length > 0 && (
              <div className="mb-6">
                <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>Volumes</h4>
                <div className="space-y-2">
                  {selectedService.mounts.map((mount, idx) => (
                    <div key={idx} className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                      <div className="text-sm mb-1">
                        <span className="px-2 py-1 rounded text-xs mr-2" style={{ background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : 'rgba(100, 116, 139, 0.3)', color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-secondary)' }}>
                          {mount.type}
                        </span>
                        {mount.mode && (
                          <span className="text-xs" style={{ color: 'var(--text-secondary)' }}>({mount.mode})</span>
                        )}
                      </div>
                      <div className="text-sm font-mono" style={{ color: 'var(--text-primary)' }}>
                        {mount.source}
                      </div>
                      <div className="text-xs mt-1" style={{ color: 'var(--text-secondary)' }}>
                        → {mount.destination}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Container Info */}
            <div className="mb-6">
              <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>Container</h4>
              <div className="space-y-2">
                <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                  <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Name</div>
                  <div className="text-sm font-mono" style={{ color: 'var(--text-primary)' }}>{selectedService.container}</div>
                </div>
                {selectedService.image && (
                  <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                    <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Image</div>
                    <div className="text-sm font-mono" style={{ color: 'var(--text-primary)' }}>{selectedService.image}</div>
                  </div>
                )}
              </div>
            </div>

            {/* Environment Variables */}
            {selectedService.env_vars && selectedService.env_vars.length > 0 && (
              <div className="mb-6">
                <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>Environment Variables</h4>
                <div className="p-3 rounded overflow-x-auto" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                  <pre className="text-xs font-mono whitespace-pre-wrap break-all" style={{ color: 'var(--text-secondary)' }}>
                    {selectedService.env_vars.join('\n')}
                  </pre>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </ProtectedRoute>
  );
}
