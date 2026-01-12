export interface Agent {
  agent_id: string;
  hostname: string;
  tenant_id: string;
  last_seen: string | null;
  status: 'online' | 'offline' | 'dead' | 'unknown';
  os_type: string | null;
  os_version: string | null;
  agent_type: string;
  agent_role?: 'agent' | 'collector';
  architecture?: string | null;
  kernel_version?: string | null;
  mac_addresses?: string | null;
  network_interfaces?: string | null;
}

export interface AgentListResponse {
  agents: Agent[];
  total: number;
  limit: number;
  offset: number;
}

export interface AgentStatusBreakdown {
  online: number;
  offline: number;
  dead: number;
  unknown: number;
  total: number;
}
