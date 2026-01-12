'use client';

import { useEffect, useState } from 'react';
import { useTheme } from '@/contexts/ThemeContext';
import { tokenUtils } from '@/lib/auth';

interface TimelineEntry {
  timestamp: string;
  old_status: string | null;
  new_status: string;
}

interface AgentTimelineResponse {
  agent_id: string;
  timeline: TimelineEntry[];
  total: number;
}

interface AgentTimelineProps {
  agentId: string;
  days?: number;
}

export default function AgentTimeline({ agentId, days = 7 }: AgentTimelineProps) {
  const { theme } = useTheme();
  const [loading, setLoading] = useState(true);
  const [timeline, setTimeline] = useState<TimelineEntry[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchTimeline();
  }, [agentId, days]);

  const fetchTimeline = async () => {
    try {
      const token = tokenUtils.getToken();
      if (!token) {
        setError('No authentication token');
        return;
      }

      setLoading(true);
      const response = await fetch(`/api/agents/${agentId}/timeline?days=${days}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch timeline (HTTP ${response.status})`);
      }

      const data: AgentTimelineResponse = await response.json();
      setTimeline(data.timeline || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load timeline');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return theme === 'cyber' ? '#00ff9f' : '#10b981';
      case 'offline':
        return theme === 'cyber' ? '#fbbf24' : '#f59e0b';
      case 'dead':
        return '#ef4444';
      default:
        return '#94a3b8';
    }
  };

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div
          className="animate-spin rounded-full h-8 w-8 border-b-2"
          style={{ borderColor: 'var(--primary)' }}
        ></div>
      </div>
    );
  }

  if (error) {
    return (
      <div
        className="p-4 rounded-lg text-center"
        style={{
          background: 'rgba(239, 68, 68, 0.1)',
          border: '1px solid #ef4444',
          color: '#ef4444',
        }}
      >
        {error}
      </div>
    );
  }

  if (timeline.length === 0) {
    return (
      <div
        className="p-8 rounded-lg text-center"
        style={{
          background: 'var(--card-bg)',
          border: '1px solid var(--card-border)',
        }}
      >
        <p style={{ color: 'var(--text-secondary)' }}>
          No status changes in the last {days} days
        </p>
      </div>
    );
  }

  return (
    <div
      className="p-6 rounded-lg"
      style={{
        background: 'var(--card-bg)',
        border: '1px solid var(--card-border)',
      }}
    >
      <h3
        className="text-lg font-semibold mb-4"
        style={{ color: 'var(--text-primary)' }}
      >
        Status History (Last {days} Days)
      </h3>

      <div className="space-y-3">
        {timeline.map((entry, index) => (
          <div key={index} className="flex items-start gap-4">
            {/* Timeline dot */}
            <div className="flex flex-col items-center">
              <div
                className="w-3 h-3 rounded-full"
                style={{
                  background: getStatusColor(entry.new_status),
                  boxShadow:
                    theme === 'cyber'
                      ? `0 0 10px ${getStatusColor(entry.new_status)}`
                      : 'none',
                }}
              />
              {index < timeline.length - 1 && (
                <div
                  className="w-0.5 h-8"
                  style={{
                    background: 'var(--card-border)',
                  }}
                />
              )}
            </div>

            {/* Timeline content */}
            <div className="flex-1 pb-2">
              <div className="flex items-center gap-2 mb-1">
                <span
                  className="text-sm font-medium"
                  style={{ color: 'var(--text-primary)' }}
                >
                  {entry.old_status ? (
                    <>
                      <span style={{ color: getStatusColor(entry.old_status) }}>
                        {entry.old_status}
                      </span>
                      {' → '}
                      <span style={{ color: getStatusColor(entry.new_status) }}>
                        {entry.new_status}
                      </span>
                    </>
                  ) : (
                    <span style={{ color: getStatusColor(entry.new_status) }}>
                      {entry.new_status} (initial)
                    </span>
                  )}
                </span>
              </div>
              <div
                className="text-xs"
                style={{ color: 'var(--text-secondary)' }}
              >
                {formatTimestamp(entry.timestamp)}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
