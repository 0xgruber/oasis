'use client';

import { useState, useEffect } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import { logsApi, LogEntry } from '@/lib/api';
import { format } from 'date-fns';

const SEVERITY_MAP: Record<number, { label: string; color: string }> = {
  1: { label: 'Debug', color: 'text-slate-400' },
  2: { label: 'Info', color: 'text-blue-400' },
  3: { label: 'Warning', color: 'text-yellow-400' },
  4: { label: 'Error', color: 'text-red-400' },
  5: { label: 'Critical', color: 'text-red-600' },
  6: { label: 'Fatal', color: 'text-red-800' },
};

export default function LogsPage() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalLogs, setTotalLogs] = useState(0);
  const [selectedLog, setSelectedLog] = useState<LogEntry | null>(null);
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
            <h1 className="text-2xl font-bold text-white">Logs</h1>
            <p className="text-slate-400 mt-1">
              {totalLogs.toLocaleString()} total logs
            </p>
          </div>
          <button
            onClick={fetchLogs}
            disabled={loading}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 text-white rounded-lg transition-colors"
          >
            {loading ? 'Refreshing...' : '🔄 Refresh'}
          </button>
        </div>

        {/* Error Message */}
        {error && (
          <div className="p-4 bg-red-900/50 border border-red-700 rounded-lg">
            <p className="text-red-200">{error}</p>
          </div>
        )}

        {/* Logs Table */}
        <div className="bg-slate-800 rounded-lg border border-slate-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-900 border-b border-slate-700">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Timestamp
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Severity
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Message
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700">
                {loading ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-slate-400">
                      <div className="flex items-center justify-center">
                        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
                        <span className="ml-3">Loading logs...</span>
                      </div>
                    </td>
                  </tr>
                ) : logs.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-8 text-center text-slate-400">
                      No logs found
                    </td>
                  </tr>
                ) : (
                  logs.map((log) => {
                    const severity = SEVERITY_MAP[log.severity_id] || {
                      label: 'Unknown',
                      color: 'text-slate-400',
                    };
                    return (
                      <tr
                        key={log.uuid}
                        className="hover:bg-slate-700/50 transition-colors cursor-pointer"
                        onClick={() => setSelectedLog(log)}
                      >
                        <td className="px-4 py-3 text-sm text-slate-300 whitespace-nowrap">
                          {formatTimestamp(log.timestamp)}
                        </td>
                        <td className="px-4 py-3 text-sm">
                          <span className={`font-medium ${severity.color}`}>
                            {severity.label}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-sm text-slate-300">
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
                            className="text-blue-400 hover:text-blue-300"
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
            <div className="px-4 py-3 bg-slate-900 border-t border-slate-700 flex items-center justify-between">
              <div className="text-sm text-slate-400">
                Showing {(currentPage - 1) * logsPerPage + 1} to{' '}
                {Math.min(currentPage * logsPerPage, totalLogs)} of {totalLogs}
              </div>
              <div className="flex space-x-2">
                <button
                  onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1 bg-slate-700 hover:bg-slate-600 disabled:bg-slate-800 disabled:cursor-not-allowed text-white rounded transition-colors"
                >
                  Previous
                </button>
                <span className="px-3 py-1 text-slate-300">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1 bg-slate-700 hover:bg-slate-600 disabled:bg-slate-800 disabled:cursor-not-allowed text-white rounded transition-colors"
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
          className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedLog(null)}
        >
          <div
            className="bg-slate-800 rounded-lg border border-slate-700 max-w-4xl w-full max-h-[80vh] overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-6 border-b border-slate-700 flex items-center justify-between">
              <h2 className="text-xl font-semibold text-white">Log Details</h2>
              <button
                onClick={() => setSelectedLog(null)}
                className="text-slate-400 hover:text-white text-2xl"
              >
                ×
              </button>
            </div>
            <div className="p-6 overflow-y-auto max-h-[calc(80vh-80px)]">
              <div className="space-y-4">
                <div>
                  <label className="text-sm font-medium text-slate-400">UUID</label>
                  <p className="text-slate-300 font-mono text-sm mt-1">{selectedLog.uuid}</p>
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-400">Timestamp</label>
                  <p className="text-slate-300 mt-1">
                    {formatTimestamp(selectedLog.timestamp)}
                  </p>
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-400">Severity</label>
                  <p className={`mt-1 ${SEVERITY_MAP[selectedLog.severity_id]?.color || 'text-slate-300'}`}>
                    {SEVERITY_MAP[selectedLog.severity_id]?.label || 'Unknown'}
                  </p>
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-400">Raw Log</label>
                  <pre className="mt-1 p-4 bg-slate-900 rounded border border-slate-700 text-slate-300 text-sm overflow-x-auto">
                    {selectedLog.raw_log}
                  </pre>
                </div>
                <div>
                  <label className="text-sm font-medium text-slate-400">OCSF Data</label>
                  <pre className="mt-1 p-4 bg-slate-900 rounded border border-slate-700 text-slate-300 text-sm overflow-x-auto">
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
