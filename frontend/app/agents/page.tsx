'use client';

import { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

interface Agent {
  agent_id: string;
  hostname: string;
  tenant_id: string;
  last_seen: string | null;
  status: 'online' | 'offline' | 'dead' | 'unknown';
  os_type: string | null;
  os_version: string | null;
  agent_type: string;
}

interface AgentListResponse {
  agents: Agent[];
  total: number;
  limit: number;
  offset: number;
}

interface AgentStatusBreakdown {
  online: number;
  offline: number;
  dead: number;
  unknown: number;
  total: number;
}

export default function AgentsPage() {
  const { user } = useAuth();
  const { theme } = useTheme();
  
  const [loading, setLoading] = useState(true);
  const [agents, setAgents] = useState<Agent[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  
  // Status breakdown
  const [breakdown, setBreakdown] = useState<AgentStatusBreakdown | null>(null);
  
  // Filters
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [searchTerm, setSearchTerm] = useState<string>('');
  
  // Pagination
  const [limit] = useState(50);
  const [offset, setOffset] = useState(0);

  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);

  const fetchBreakdown = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) return;

      const response = await fetch('/api/agents/status', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) return;

      const data = await response.json();
      setBreakdown(data);
    } catch (err) {
      console.error('Failed to load agent status breakdown:', err);
    }
  };

  const fetchAgents = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) {
        throw new Error('No authentication token found');
      }

      let url = `/api/agents?limit=${limit}&offset=${offset}`;
      if (statusFilter) {
        url += `&status=${statusFilter}`;
      }

      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to load agents (HTTP ${response.status})`);
      }

      const data: AgentListResponse = await response.json();
      setAgents(data.agents || []);
      setTotal(data.total || 0);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load agents');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAgents();
    fetchBreakdown();
  }, [statusFilter, offset]);

  const getStatusBadgeStyle = (status: string) => {
    const baseStyle = 'px-2 py-1 rounded text-xs font-semibold';
    
    switch (status) {
      case 'online':
        return {
          className: `${baseStyle}`,
          style: {
            background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : 'rgba(16, 185, 129, 0.1)',
            color: theme === 'cyber' ? '#00ff9f' : '#10b981',
            border: `1px solid ${theme === 'cyber' ? '#00ff9f' : '#10b981'}`,
          }
        };
      case 'offline':
        return {
          className: `${baseStyle}`,
          style: {
            background: theme === 'cyber' ? 'rgba(251, 191, 36, 0.2)' : 'rgba(251, 191, 36, 0.1)',
            color: theme === 'cyber' ? '#fbbf24' : '#f59e0b',
            border: `1px solid ${theme === 'cyber' ? '#fbbf24' : '#f59e0b'}`,
          }
        };
      case 'dead':
        return {
          className: `${baseStyle}`,
          style: {
            background: theme === 'cyber' ? 'rgba(239, 68, 68, 0.2)' : 'rgba(239, 68, 68, 0.1)',
            color: '#ef4444',
            border: '1px solid #ef4444',
          }
        };
      default:
        return {
          className: `${baseStyle}`,
          style: {
            background: 'rgba(148, 163, 184, 0.1)',
            color: '#94a3b8',
            border: '1px solid #94a3b8',
          }
        };
    }
  };

  const formatLastSeen = (lastSeen: string | null) => {
    if (!lastSeen) return 'Never';
    
    const date = new Date(lastSeen);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 30) return `${diffDays}d ago`;
    
    const diffMonths = Math.floor(diffDays / 30);
    return `${diffMonths}mo ago`;
  };

  const filteredAgents = agents.filter(agent => {
    if (!searchTerm) return true;
    return agent.hostname.toLowerCase().includes(searchTerm.toLowerCase()) ||
           agent.agent_id.toLowerCase().includes(searchTerm.toLowerCase());
  });

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2" style={{ borderColor: 'var(--primary)' }}></div>
      </div>
    );
  }

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <h1 
          className={`text-3xl font-bold mb-2 ${theme === 'cyber' ? 'glitch-text' : ''}`}
          style={{ color: 'var(--text-primary)' }}
        >
          Agent Management
        </h1>
        <p style={{ color: 'var(--text-secondary)' }}>
          Monitor and manage all deployed agents across tenants
        </p>
      </div>

      {/* Status Cards */}
      {breakdown && (
        <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-6">
          <div 
            className="p-4 rounded-lg"
            style={{
              background: 'var(--card-bg)',
              border: `1px solid var(--card-border)`,
            }}
          >
            <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>Total Agents</div>
            <div className="text-2xl font-bold mt-1" style={{ color: 'var(--text-primary)' }}>
              {breakdown.total}
            </div>
          </div>
          
          <div 
            className="p-4 rounded-lg cursor-pointer hover:opacity-80 transition-opacity"
            style={{
              background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.1)' : 'rgba(16, 185, 129, 0.1)',
              border: `1px solid ${theme === 'cyber' ? '#00ff9f' : '#10b981'}`,
            }}
            onClick={() => setStatusFilter(statusFilter === 'online' ? '' : 'online')}
          >
            <div className="text-sm" style={{ color: theme === 'cyber' ? '#00ff9f' : '#10b981' }}>Online</div>
            <div className="text-2xl font-bold mt-1" style={{ color: theme === 'cyber' ? '#00ff9f' : '#10b981' }}>
              {breakdown.online}
            </div>
          </div>
          
          <div 
            className="p-4 rounded-lg cursor-pointer hover:opacity-80 transition-opacity"
            style={{
              background: theme === 'cyber' ? 'rgba(251, 191, 36, 0.1)' : 'rgba(251, 191, 36, 0.1)',
              border: `1px solid ${theme === 'cyber' ? '#fbbf24' : '#f59e0b'}`,
            }}
            onClick={() => setStatusFilter(statusFilter === 'offline' ? '' : 'offline')}
          >
            <div className="text-sm" style={{ color: theme === 'cyber' ? '#fbbf24' : '#f59e0b' }}>Offline</div>
            <div className="text-2xl font-bold mt-1" style={{ color: theme === 'cyber' ? '#fbbf24' : '#f59e0b' }}>
              {breakdown.offline}
            </div>
          </div>
          
          <div 
            className="p-4 rounded-lg cursor-pointer hover:opacity-80 transition-opacity"
            style={{
              background: 'rgba(239, 68, 68, 0.1)',
              border: '1px solid #ef4444',
            }}
            onClick={() => setStatusFilter(statusFilter === 'dead' ? '' : 'dead')}
          >
            <div className="text-sm" style={{ color: '#ef4444' }}>Dead</div>
            <div className="text-2xl font-bold mt-1" style={{ color: '#ef4444' }}>
              {breakdown.dead}
            </div>
          </div>
          
          <div 
            className="p-4 rounded-lg cursor-pointer hover:opacity-80 transition-opacity"
            style={{
              background: 'rgba(148, 163, 184, 0.1)',
              border: '1px solid #94a3b8',
            }}
            onClick={() => setStatusFilter(statusFilter === 'unknown' ? '' : 'unknown')}
          >
            <div className="text-sm" style={{ color: '#94a3b8' }}>Unknown</div>
            <div className="text-2xl font-bold mt-1" style={{ color: '#94a3b8' }}>
              {breakdown.unknown}
            </div>
          </div>
        </div>
      )}

      {/* Filters and Search */}
      <div className="mb-6 flex gap-4">
        <input
          type="text"
          placeholder="Search by hostname or agent ID..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="flex-1 px-4 py-2 rounded-lg"
          style={{
            background: 'var(--input-bg)',
            border: `1px solid var(--input-border)`,
            color: 'var(--text-primary)',
          }}
        />
        
        {statusFilter && (
          <button
            onClick={() => setStatusFilter('')}
            className="px-4 py-2 rounded-lg text-sm font-medium transition-colors"
            style={{
              background: 'rgba(239, 68, 68, 0.1)',
              color: '#ef4444',
              border: '1px solid #ef4444',
            }}
          >
            Clear Filter
          </button>
        )}
      </div>

      {/* Error Message */}
      {error && (
        <div 
          className="mb-6 p-4 rounded-lg"
          style={{
            background: 'rgba(239, 68, 68, 0.1)',
            border: '1px solid #ef4444',
            color: '#ef4444',
          }}
        >
          {error}
        </div>
      )}

      {/* Agents Table */}
      <div 
        className="rounded-lg overflow-hidden"
        style={{
          background: 'var(--card-bg)',
          border: `1px solid var(--card-border)`,
        }}
      >
        <table className="w-full">
          <thead style={{ background: 'var(--table-header-bg)', borderBottom: `1px solid var(--card-border)` }}>
            <tr>
              <th className="text-left px-6 py-3 text-xs font-semibold uppercase" style={{ color: 'var(--text-secondary)' }}>
                Status
              </th>
              <th className="text-left px-6 py-3 text-xs font-semibold uppercase" style={{ color: 'var(--text-secondary)' }}>
                Hostname
              </th>
              <th className="text-left px-6 py-3 text-xs font-semibold uppercase" style={{ color: 'var(--text-secondary)' }}>
                OS
              </th>
              <th className="text-left px-6 py-3 text-xs font-semibold uppercase" style={{ color: 'var(--text-secondary)' }}>
                Agent Type
              </th>
              <th className="text-left px-6 py-3 text-xs font-semibold uppercase" style={{ color: 'var(--text-secondary)' }}>
                Last Seen
              </th>
              <th className="text-left px-6 py-3 text-xs font-semibold uppercase" style={{ color: 'var(--text-secondary)' }}>
                Agent ID
              </th>
            </tr>
          </thead>
          <tbody>
            {filteredAgents.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-6 py-8 text-center" style={{ color: 'var(--text-secondary)' }}>
                  No agents found
                </td>
              </tr>
            ) : (
              filteredAgents.map((agent, idx) => {
                const badge = getStatusBadgeStyle(agent.status);
                return (
                  <tr
                    key={agent.agent_id}
                    style={{ 
                      borderBottom: idx < filteredAgents.length - 1 ? `1px solid var(--card-border)` : undefined 
                    }}
                    className="hover:bg-opacity-50 transition-colors"
                  >
                    <td className="px-6 py-4">
                      <span className={badge.className} style={badge.style}>
                        {agent.status.toUpperCase()}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="font-medium" style={{ color: 'var(--text-primary)' }}>
                        {agent.hostname}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div style={{ color: 'var(--text-primary)' }}>
                        {agent.os_type || 'Unknown'}
                      </div>
                      {agent.os_version && (
                        <div className="text-xs" style={{ color: 'var(--text-secondary)' }}>
                          {agent.os_version}
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4" style={{ color: 'var(--text-primary)' }}>
                      {agent.agent_type}
                    </td>
                    <td className="px-6 py-4" style={{ color: 'var(--text-secondary)' }}>
                      {formatLastSeen(agent.last_seen)}
                    </td>
                    <td className="px-6 py-4">
                      <code className="text-xs" style={{ color: 'var(--text-secondary)' }}>
                        {agent.agent_id.substring(0, 8)}...
                      </code>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {total > limit && (
        <div className="mt-6 flex items-center justify-between">
          <div style={{ color: 'var(--text-secondary)' }}>
            Showing {offset + 1} - {Math.min(offset + limit, total)} of {total}
          </div>
          <div className="flex gap-2">
            <button
              disabled={offset === 0}
              onClick={() => setOffset(Math.max(0, offset - limit))}
              className="px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              style={{
                background: 'var(--button-bg)',
                border: `1px solid var(--button-border)`,
                color: 'var(--text-primary)',
              }}
            >
              Previous
            </button>
            <button
              disabled={offset + limit >= total}
              onClick={() => setOffset(offset + limit)}
              className="px-4 py-2 rounded-lg text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              style={{
                background: 'var(--button-bg)',
                border: `1px solid var(--button-border)`,
                color: 'var(--text-primary)',
              }}
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
