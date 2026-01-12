'use client';

import { Agent } from '@/types/agent';
import { useTheme } from '@/contexts/ThemeContext';
import { useEffect } from 'react';

interface AgentsModalProps {
  agent: Agent | null;
  onClose: () => void;
  formatLastSeen: (lastSeen: string | null) => string;
}

export default function AgentsModal({ agent, onClose, formatLastSeen }: AgentsModalProps) {
  const { theme } = useTheme();

  useEffect(() => {
    const handleEscKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', handleEscKey);
    return () => document.removeEventListener('keydown', handleEscKey);
  }, [onClose]);

  if (!agent) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         onClick={onClose}>
      <div className="rounded-lg p-6 max-w-4xl max-h-[85vh] overflow-y-auto w-full"
           style={{
             background: theme === 'cyber' ? 'rgba(15, 23, 42, 0.98)' : '#1e293b',
             border: theme === 'cyber' ? '1px solid rgba(0, 255, 159, 0.3)' : '1px solid #475569'
           }}
           onClick={(e) => e.stopPropagation()}>
        
        <div className="flex items-center justify-between mb-4 pb-4 border-b"
             style={{ borderColor: theme === 'cyber' ? 'rgba(0, 255, 159, 0.2)' : '#475569' }}>
          <h3 className="text-2xl font-bold"
              style={{ color: theme === 'cyber' ? 'var(--cyber-green)' : 'var(--text-primary)' }}>
            Agent Details
          </h3>
          <button onClick={onClose}
                  className="text-2xl hover:opacity-70 transition-opacity"
                  style={{ color: 'var(--text-secondary)' }}>
            ✕
          </button>
        </div>

        <div className="mb-6">
          <h4 className="text-lg font-semibold mb-3"
              style={{ color: 'var(--text-primary)' }}>
            Basic Information
          </h4>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div className="p-3 rounded"
                 style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
              <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Status</div>
              <div className="font-medium">
                <span className={`px-2 py-1 rounded text-xs ${
                  agent.status === 'online' ? 'bg-green-100 text-green-800' :
                  agent.status === 'offline' ? 'bg-yellow-100 text-yellow-800' :
                  agent.status === 'dead' ? 'bg-red-100 text-red-800' :
                  'bg-gray-100 text-gray-800'
                }`}>
                  {agent.status.toUpperCase()}
                </span>
          </div>
        </div>

        <div className="mb-6">
          <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
            System Information
          </h4>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">

            {agent.architecture && (
              <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Architecture</div>
                <div className="font-medium" style={{ color: 'var(--text-primary)' }}>
                  {agent.architecture}
                </div>
              </div>
            )}

            {agent.kernel_version && (
              <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Kernel Version</div>
                <div className="font-medium" style={{ color: 'var(--text-primary)' }}>
                  {agent.kernel_version}
                </div>
              </div>
            )}

            {agent.network_interfaces && (
              <div className="p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>Network Interfaces</div>
                <div className="font-medium text-xs" style={{ color: 'var(--text-primary)' }}>
                  {agent.network_interfaces}
                </div>
              </div>
            )}

            {agent.mac_addresses && (
              <div className="p-3 rounded col-span-2" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
                <div className="text-xs mb-2" style={{ color: 'var(--text-secondary)' }}>MAC Addresses</div>
                <div className="font-mono text-xs space-y-1" style={{ color: 'var(--text-primary)' }}>
                  {agent.mac_addresses.split(';').map((mac, i) => (
                    <div key={i}>{mac}</div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="mb-6">
          <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
            Identification
          </h4>
          <div className="space-y-2">
            <div className="flex justify-between p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
              <span style={{ color: 'var(--text-secondary)' }}>Agent ID</span>
              <code className="text-xs" style={{ color: 'var(--text-primary)' }}>
                {agent.agent_id}
              </code>
            </div>
            <div className="flex justify-between p-3 rounded" style={{ background: 'rgba(0, 0, 0, 0.3)' }}>
              <span style={{ color: 'var(--text-secondary)' }}>Tenant ID</span>
              <code className="text-xs" style={{ color: 'var(--text-primary)' }}>
                {agent.tenant_id}
              </code>
            </div>
          </div>
        </div>

        <div className="mb-6">
          <h4 className="text-lg font-semibold mb-3" style={{ color: 'var(--text-primary)' }}>
            Metrics
          </h4>
          <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>
            Agent metrics coming in Phase 2C...
          </div>
        </div>
      </div>
    </div>
  );
}
