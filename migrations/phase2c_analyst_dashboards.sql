-- Phase 2C: S.O.C.A.P. - Analyst Dashboards & Workflows Schema Updates
-- This migration adds dashboard_templates and agent_timeline tracking tables

-- ==================================================================
-- 1. Dashboard Templates Table
-- ==================================================================

CREATE TABLE IF NOT EXISTS dashboard_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_template BOOLEAN DEFAULT false,  -- If true, can be used by other analysts
    widgets JSONB NOT NULL DEFAULT '[]'::jsonb,  -- Array of widget configurations
    
    -- Dashboard filtering options
    tenant_scope VARCHAR(20) DEFAULT 'all' CHECK (tenant_scope IN ('all', 'subscribed', 'specific')),
    tenant_ids UUID[] DEFAULT NULL,  -- Specific tenant IDs if scope is 'specific'
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ,
    
    -- Soft delete support
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_dashboard_templates_owner ON dashboard_templates(owner_id);
CREATE INDEX idx_dashboard_templates_is_template ON dashboard_templates(is_template, is_deleted);
CREATE INDEX idx_dashboard_templates_updated_at ON dashboard_templates(updated_at DESC);
CREATE INDEX idx_dashboard_templates_tenant_scope ON dashboard_templates(tenant_scope);

COMMENT ON TABLE dashboard_templates IS 'Custom dashboards for SOC analysts with customizable widgets';
COMMENT ON COLUMN dashboard_templates.widgets IS 'Array of widget definitions (type, size, config, query)';
COMMENT ON COLUMN dashboard_templates.tenant_scope IS 'Data scope: all tenants, subscribed tenants only, or specific tenants';
COMMENT ON COLUMN dashboard_templates.is_template IS 'If true, this dashboard can be copied/studied by other analysts';

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_dashboard_templates_updated_at
    BEFORE UPDATE ON dashboard_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update last_accessed_at (will be updated on GET requests)
CREATE OR REPLACE FUNCTION update_last_accessed_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_accessed_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==================================================================
-- 2. Agent Timeline Tracking Table
-- ==================================================================

CREATE TABLE IF NOT EXISTS agent_status_timeline (
    id BIGSERIAL PRIMARY KEY,
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    
    status VARCHAR(20) NOT NULL CHECK (status IN ('online', 'offline', 'dead', 'unknown')),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Additional context
    source VARCHAR(50) DEFAULT 'heartbeat',  -- heartbeat, manual_check, ingestion
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Indexes for efficient timeline queries
    UNIQUE(agent_id, timestamp, source)
);

CREATE INDEX idx_agent_timeline_agent ON agent_status_timeline(agent_id);
CREATE INDEX idx_agent_timeline_timestamp ON agent_status_timeline(timestamp DESC);
CREATE INDEX idx_agent_timeline_status ON agent_status_timeline(status);
CREATE INDEX idx_agent_timeline_agent_timestamp ON agent_status_timeline(agent_id, timestamp DESC);

COMMENT ON TABLE agent_status_timeline IS 'Historical tracking of agent status changes for timeline visualization';
COMMENT ON COLUMN agent_status_timeline.source IS 'Source of status change: heartbeat (agent check-in), manual_check (manual status), ingestion (log-based check)';

-- Auto-cleanup: Delete timeline entries older than 90 days to prevent unbounded growth
CREATE OR REPLACE FUNCTION cleanup_old_agent_timeline()
RETURNS void AS $$
BEGIN
    DELETE FROM agent_status_timeline
    WHERE timestamp < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- ==================================================================
-- 3. Agent Timeline Trigger Function
-- ==================================================================

-- Trigger to log status changes when agents update
CREATE OR REPLACE FUNCTION log_agent_status_change()
RETURNS TRIGGER AS $$
DECLARE
    old_status VARCHAR(20);
    new_status VARCHAR(20);
    threshold_offline INTEGER;
    threshold_dead INTEGER;
BEGIN
    -- Get the tenant's offline/dead thresholds
    SELECT COALESCE(agent_offline_threshold, 480),
           COALESCE(agent_dead_threshold, 43200)
    INTO threshold_offline, threshold_dead
    FROM tenant_settings
    WHERE tenant_id = NEW.tenant_id;

    -- Use system defaults if tenant settings don't exist
    IF threshold_offline IS NULL THEN
        SELECT value::integer INTO threshold_offline
        FROM system_config
        WHERE key = 'agent_offline_threshold';
    END IF;
    IF threshold_dead IS NULL THEN
        SELECT value::integer INTO threshold_dead
        FROM system_config
        WHERE key = 'agent_dead_threshold';
    END IF;

    -- Calculate new status based on last_seen
    IF NEW.last_seen > NOW() - (threshold_offline || ' minutes')::interval THEN
        new_status := 'online';
    ELSIF NEW.last_seen > NOW() - (threshold_dead || ' minutes')::interval THEN
        new_status := 'offline';
    ELSE
        new_status := 'dead';
    END IF;

    -- Only log if status actually changed
    IF TG_OP = 'INSERT' THEN
        INSERT INTO agent_status_timeline (agent_id, status, source, metadata)
        VALUES (NEW.id, new_status, 'heartbeat', '{"event": "agent_created"}');
    ELSIF TG_OP = 'UPDATE' THEN
        -- Get old status
        IF OLD.last_seen > NOW() - (threshold_offline || ' minutes')::interval THEN
            old_status := 'online';
        ELSIF OLD.last_seen > NOW() - (threshold_dead || ' minutes')::interval THEN
            old_status := 'offline';
        ELSE
            old_status := 'dead';
        END IF;

        IF old_status != new_status THEN
            INSERT INTO agent_status_timeline (agent_id, status, source, metadata)
            VALUES (NEW.id, new_status, 'heartbeat', 
                    jsonb_build_object(
                        'previous_status', old_status,
                        'last_seen', EXTRACT(EPOCH FROM NEW.last_seen)::bigint
                    ));
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on agents table
DROP TRIGGER IF EXISTS trigger_agent_status_timeline ON agents;
CREATE TRIGGER trigger_agent_status_timeline
    AFTER INSERT OR UPDATE OF last_seen ON agents
    FOR EACH ROW
    EXECUTE FUNCTION log_agent_status_change();

-- ==================================================================
-- 4. Insert Default Dashboard Templates
-- ==================================================================

-- Default SOC Overview Dashboard
INSERT INTO dashboard_templates (name, description, owner_id, is_template, widgets, tenant_scope)
SELECT 
    'SOC Overview',
    'High-level overview of all system activity',
    id,
    true,
    '[
        {
            "id": "logs_volume",
            "type": "timeseries_chart",
            "title": "Log Volume (24h)",
            "size": { "w": 6, "h": 3 },
            "config": { "metric": "log_volume", "time_range": "24h", "color": "#00ff9f" }
        },
        {
            "id": "agent_status",
            "type": "status_cards",
            "title": "Agent Status",
            "size": { "w": 6, "h": 2 },
            "config": { "show_breakdown": true }
        },
        {
            "id": "top_sources",
            "type": "bar_chart",
            "title": "Top Log Sources",
            "size": { "w": 4, "h": 3 },
            "config": { "limit": 10, "time_range": "24h" }
        },
        {
            "id": "severity_breakdown",
            "type": "donut_chart",
            "title": "Severity Distribution",
            "size": { "w": 4, "h": 3 },
            "config": { "time_range": "24h" }
        },
        {
            "id": "recent_alerts",
            "type": "log_table",
            "title": "Critical Events",
            "size": { "w": 12, "h": 4 },
            "config": { "severity": "critical", "limit": 20 }
        }
    ]'::jsonb,
    'all'
FROM users
WHERE role = 'platform_admin'
LIMIT 1;

-- Default Tenant Health Dashboard
INSERT INTO dashboard_templates (name, description, owner_id, is_template, widgets, tenant_scope)
SELECT 
    'Tenant Health',
    'Detailed view of tenant-specific metrics',
    id,
    true,
    '[
        {
            "id": "tenant_logs",
            "type": "timeseries_chart",
            "title": "Log Volume by Tenant",
            "size": { "w": 8, "h": 4 },
            "config": { "group_by": "tenant_id", "time_range": "24h" }
        },
        {
            "id": "tenant_agents",
            "type": "agent_list",
            "title": "Agents by Tenant",
            "size": { "w": 4, "h": 4 },
            "config": { "group_by": "tenant_id", "show_status": true }
        }
    ]'::jsonb,
    'subscribed'
FROM users
WHERE role = 'platform_admin'
LIMIT 1;

-- ==================================================================
-- 5. Grant Permissions
-- ==================================================================

-- Grant API user permissions on new tables
GRANT SELECT, INSERT, UPDATE, DELETE ON dashboard_templates TO api_user;
GRANT SELECT, USAGE ON ALL SEQUENCES IN SCHEMA public TO api_user;

GRANT SELECT, INSERT, DELETE ON agent_status_timeline TO api_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_user;

GRANT SELECT ON agent_status_timeline TO metrics_user;

-- ==================================================================
-- End of Phase 2C Schema Migration
-- ==================================================================

-- Verify migration
SELECT 'Phase 2C schema migration completed successfully' AS status;
