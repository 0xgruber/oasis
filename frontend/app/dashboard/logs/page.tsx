'use client';

import { useState, useEffect } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useTheme } from '@/contexts/ThemeContext';
import { logsApi, LogEntry } from '@/lib/api';
import { format } from 'date-fns';

const SEVERITY_MAP: Record<number, { 
  label: string; 
  color: string; 
  cyberColor: string;
  cyberGlow: string;
}> = {
  1: { label: 'Debug', color: 'text-slate-400', cyberColor: '#00d4ff', cyberGlow: '0 0 10px #00d4ff' },
  2: { label: 'Info', color: 'text-blue-400', cyberColor: '#00d4ff', cyberGlow: '0 0 10px #00d4ff' },
  3: { label: 'Warning', color: 'text-yellow-400', cyberColor: '#ffff00', cyberGlow: '0 0 10px #ffff00' },
  4: { label: 'Error', color: 'text-red-400', cyberColor: '#ff0055', cyberGlow: '0 0 10px #ff0055' },
  5: { label: 'Critical', color: 'text-red-600', cyberColor: '#ff00ff', cyberGlow: '0 0 10px #ff00ff' },
  6: { label: 'Fatal', color: 'text-red-800', cyberColor: '#ff00ff', cyberGlow: '0 0 15px #ff00ff' },
};

export default function LogsPage() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalLogs, setTotalLogs] = useState(0);
  const [selectedLog, setSelectedLog] = useState<LogEntry | null>(null);
  const { theme } = useTheme();
  const logsPerPage = 50;

  useEffect(() => {
    fetchLogs();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage]);

  const fetchLogs = async () => {
    setLoading(true);
    setError(null);

    try {
      const offset = (currentPage - 1) * logsPerPage;
      const response = await logsApi.getLogs({
        limit: logsPerPage,
        offset,
      });

      setLogs(response.logs);
      setTotalLogs(response.total);
    } catch (err) {
      const error = err as { response?: { data?: { detail?: string } } };
      setError(error.response?.data?.detail || 'Failed to fetch logs');
      console.error('Error fetching logs:', err);
    } finally {
      setLoading(false);
    }
  };

  const totalPages = Math.ceil(totalLogs / logsPerPage);

  const formatTimestamp = (timestamp: number) => {
    return format(new Date(timestamp), 'yyyy-MM-dd HH:mm:ss');
  };

  return (
    <ProtectedRoute>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 
              className={`text-2xl font-bold ${theme === 'cyber' ? 'text-glow-subtle' : 'text-white'}`}
              style={{ color: 'var(--text-primary)' }}
            >
              Logs
            </h1>
            <p className="mt-1" style={{ color: 'var(--text-secondary)' }}>
              {totalLogs.toLocaleString()} total logs
            </p>
          </div>
          <button
            onClick={fetchLogs}
            disabled={loading}
            className="px-4 py-2 rounded-lg transition-colors"
            style={{
              background: theme === 'cyber' ? 'var(--primary)' : '#2563eb',
              color: theme === 'cyber' ? '#0a0e27' : '#ffffff',
              opacity: loading ? 0.5 : 1,
              boxShadow: theme === 'cyber' && !loading ? '0 0 15px var(--primary)' : undefined
            }}
          >
            {loading ? 'Refreshing...' : '🔄 Refresh'}
          </button>
        </div>

        {/* Error Message */}
        {error && (
          <div 
            className="p-4 rounded-lg"
            style={{
              background: theme === 'cyber' ? 'rgba(255, 0, 85, 0.1)' : 'rgba(127, 29, 29, 0.5)',
              border: theme === 'cyber' ? '1px solid #ff0055' : '1px solid rgb(185, 28, 28)'
            }}
          >
            <p style={{ color: theme === 'cyber' ? '#ff0055' : 'rgb(252, 165, 165)' }}>{error}</p>
          </div>
        )}

        {/* Logs Table */}
        <div 
          className={`rounded-lg overflow-hidden ${theme === 'cyber' ? 'terminal-card' : 'bg-slate-800 border border-slate-700'}`}
          style={{ 
            background: 'var(--card-bg)',
            border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
          }}
        >
          {theme === 'cyber' && (
            <div className="terminal-dots p-4">
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
              <div className="terminal-dot"></div>
            </div>
          )}
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead 
                style={{ 
                  background: 'var(--table-header)',
                  borderBottom: theme === 'cyber' ? '1px solid var(--card-border)' : '1px solid #334155'
                }}
              >
                <tr>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Timestamp
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Severity
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Message
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody style={{ borderTop: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.2)' : undefined }}>
                {loading ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center" style={{ color: 'var(--text-secondary)' }}>
                      <div className="flex items-center justify-center">
                        <div 
                          className="animate-spin rounded-full h-8 w-8 border-b-2"
                          style={{ borderColor: theme === 'cyber' ? 'var(--primary)' : '#3b82f6' }}
                        ></div>
                        <span className="ml-3">Loading logs...</span>
                      </div>
                    </td>
                  </tr>
                ) : logs.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center" style={{ color: 'var(--text-secondary)' }}>
                      No logs found
                    </td>
                  </tr>
                ) : (
                  logs.map((log) => {
                    const severity = SEVERITY_MAP[log.severity_id] || {
                      label: 'Unknown',
                      color: 'text-slate-400',
                      cyberColor: '#00d4ff',
                      cyberGlow: '0 0 10px #00d4ff'
                    };
                    return (
                      <tr
                        key={log.uuid}
                        className="transition-colors cursor-pointer"
                        style={{
                          background: 'var(--table-row)',
                          borderBottom: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.1)' : '1px solid #334155'
                        }}
                        onClick={() => setSelectedLog(log)}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.background = 'var(--table-row-hover)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.background = 'var(--table-row)';
                        }}
                      >
                        <td 
                          className="px-4 py-3 text-sm whitespace-nowrap"
                          style={{ color: 'var(--text-primary)' }}
                        >
                          {formatTimestamp(log.timestamp)}
                        </td>
                        <td className="px-4 py-3 text-sm">
                          <span 
                            className={`font-medium ${theme === 'cyber' ? '' : severity.color}`}
                            style={theme === 'cyber' ? { 
                              color: severity.cyberColor,
                              textShadow: severity.cyberGlow
                            } : undefined}
                          >
                            {severity.label}
                          </span>
                        </td>
                        <td 
                          className="px-4 py-3 text-sm"
                          style={{ color: 'var(--text-primary)' }}
                        >
                          <div className="max-w-2xl truncate">
                            {log.message || log.raw_log.substring(0, 100)}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-sm">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedLog(log);
                            }}
                            style={{ color: theme === 'cyber' ? 'var(--cyber-cyan)' : '#60a5fa' }}
                            className="hover:underline"
                          >
                            View
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {!loading && logs.length > 0 && (
            <div 
              className="px-4 py-3 flex items-center justify-between"
              style={{ 
                background: 'var(--table-header)',
                borderTop: theme === 'cyber' ? '1px solid var(--card-border)' : '1px solid #334155'
              }}
            >
              <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                Showing {(currentPage - 1) * logsPerPage + 1} to{' '}
                {Math.min(currentPage * logsPerPage, totalLogs)} of {totalLogs}
              </div>
              <div className="flex space-x-2">
                <button
                  onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1 rounded transition-colors"
                  style={{
                    background: currentPage === 1 
                      ? (theme === 'cyber' ? 'rgba(0, 255, 159, 0.1)' : '#1e293b')
                      : (theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : '#334155'),
                    color: currentPage === 1 ? 'var(--text-secondary)' : 'var(--text-primary)',
                    cursor: currentPage === 1 ? 'not-allowed' : 'pointer',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : undefined
                  }}
                >
                  Previous
                </button>
                <span 
                  className="px-3 py-1"
                  style={{ color: 'var(--text-primary)' }}
                >
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1 rounded transition-colors"
                  style={{
                    background: currentPage === totalPages
                      ? (theme === 'cyber' ? 'rgba(0, 255, 159, 0.1)' : '#1e293b')
                      : (theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : '#334155'),
                    color: currentPage === totalPages ? 'var(--text-secondary)' : 'var(--text-primary)',
                    cursor: currentPage === totalPages ? 'not-allowed' : 'pointer',
                    border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : undefined
                  }}
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Log Detail Modal */}
      {selectedLog && (
        <div
          className="fixed inset-0 flex items-center justify-center z-50 p-4"
          style={{ background: 'rgba(0, 0, 0, 0.7)' }}
          onClick={() => setSelectedLog(null)}
        >
          <div
            className={`rounded-lg max-w-4xl w-full max-h-[80vh] overflow-hidden ${theme === 'cyber' ? 'terminal-card' : 'bg-slate-800 border border-slate-700'}`}
            style={{ 
              background: 'var(--modal-bg)',
              border: theme === 'cyber' ? '2px solid var(--card-border)' : undefined
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {theme === 'cyber' && (
              <div className="terminal-dots p-4">
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
                <div className="terminal-dot"></div>
              </div>
            )}
            <div 
              className="p-6 flex items-center justify-between"
              style={{ borderBottom: `1px solid ${theme === 'cyber' ? 'var(--card-border)' : '#334155'}` }}
            >
              <h2 
                className={`text-xl font-semibold ${theme === 'cyber' ? 'text-glow-subtle' : ''}`}
                style={{ color: 'var(--text-primary)' }}
              >
                Log Details
              </h2>
              <button
                onClick={() => setSelectedLog(null)}
                className="text-2xl transition-colors"
                style={{ color: 'var(--text-secondary)' }}
                onMouseEnter={(e) => e.currentTarget.style.color = 'var(--text-primary)'}
                onMouseLeave={(e) => e.currentTarget.style.color = 'var(--text-secondary)'}
              >
                ×
              </button>
            </div>
            <div className="p-6 overflow-y-auto max-h-[calc(80vh-80px)]">
              <div className="space-y-4">
                <div>
                  <label 
                    className="text-sm font-medium"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    UUID
                  </label>
                  <p 
                    className="font-mono text-sm mt-1"
                    style={{ color: 'var(--text-primary)' }}
                  >
                    {selectedLog.uuid}
                  </p>
                </div>
                <div>
                  <label 
                    className="text-sm font-medium"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Timestamp
                  </label>
                  <p 
                    className="mt-1"
                    style={{ color: 'var(--text-primary)' }}
                  >
                    {formatTimestamp(selectedLog.timestamp)}
                  </p>
                </div>
                <div>
                  <label 
                    className="text-sm font-medium"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Severity
                  </label>
                  <p 
                    className={`mt-1 ${theme === 'cyber' ? '' : SEVERITY_MAP[selectedLog.severity_id]?.color || 'text-slate-300'}`}
                    style={theme === 'cyber' ? {
                      color: SEVERITY_MAP[selectedLog.severity_id]?.cyberColor || '#00d4ff',
                      textShadow: SEVERITY_MAP[selectedLog.severity_id]?.cyberGlow || '0 0 10px #00d4ff'
                    } : undefined}
                  >
                    {SEVERITY_MAP[selectedLog.severity_id]?.label || 'Unknown'}
                  </p>
                </div>
                <div>
                  <label 
                    className="text-sm font-medium"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    Raw Log
                  </label>
                  <pre 
                    className="mt-1 p-4 rounded text-sm overflow-x-auto"
                    style={{ 
                      background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.05)' : '#0f172a',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.2)' : '1px solid #334155',
                      color: 'var(--text-primary)'
                    }}
                  >
                    {selectedLog.raw_log}
                  </pre>
                </div>
                <div>
                  <label 
                    className="text-sm font-medium"
                    style={{ color: 'var(--text-secondary)' }}
                  >
                    OCSF Data
                  </label>
                  <pre 
                    className="mt-1 p-4 rounded text-sm overflow-x-auto"
                    style={{ 
                      background: theme === 'cyber' ? 'rgba(0, 255, 159, 0.05)' : '#0f172a',
                      border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.2)' : '1px solid #334155',
                      color: 'var(--text-primary)'
                    }}
                  >
                    {JSON.stringify(selectedLog.ocsf, null, 2)}
                  </pre>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </ProtectedRoute>
  );
}
