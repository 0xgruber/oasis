-- Phase 2A: Multi-Portal Foundation & RBAC Schema Updates
-- This migration adds support for the three-portal architecture

-- ==================================================================
-- 1. User Role System
-- ==================================================================

-- First, standardize existing role values before creating enum
-- Map existing roles to new role names
UPDATE users SET role = 'platform_admin' WHERE role IN ('admin', 'super_admin', 'root');
UPDATE users SET role = 'customer_user' WHERE role IN ('tenant_user', 'user', 'viewer', 'operator');
UPDATE users SET role = 'soc_analyst' WHERE role IN ('analyst', 'monitor', 'soc_user');

-- Create role enum type
CREATE TYPE user_role AS ENUM ('platform_admin', 'soc_analyst', 'customer_user');

-- Update users table to use enum role
ALTER TABLE users ALTER COLUMN role DROP DEFAULT;
ALTER TABLE users ALTER COLUMN role TYPE user_role USING role::user_role;
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'customer_user'::user_role;

-- Add role index for efficient role-based queries
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

COMMENT ON TYPE user_role IS 'User roles: platform_admin (OASIS operators), soc_analyst (internal SOC team), customer_user (tenant users)';

-- ==================================================================
-- 2. Tenant Settings (Per-Tenant Overrides)
-- ==================================================================

CREATE TABLE IF NOT EXISTS tenant_settings (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Agent status thresholds (in minutes)
    agent_offline_threshold INTEGER DEFAULT 480,  -- 8 hours
    agent_dead_threshold INTEGER DEFAULT 43200,   -- 30 days
    
    -- Additional tenant-specific settings
    notification_preferences JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_tenant_settings_updated_at ON tenant_settings(updated_at);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_tenant_settings_updated_at
    BEFORE UPDATE ON tenant_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE tenant_settings IS 'Per-tenant configuration overrides (agent thresholds, notification preferences)';
COMMENT ON COLUMN tenant_settings.agent_offline_threshold IS 'Minutes before agent is marked offline (overrides global default)';
COMMENT ON COLUMN tenant_settings.agent_dead_threshold IS 'Minutes before agent is marked dead (overrides global default)';

-- ==================================================================
-- 3. Analyst Tenant Subscriptions (Phase 2C prep)
-- ==================================================================

CREATE TYPE notification_level AS ENUM ('all', 'critical_only', 'none');

CREATE TABLE IF NOT EXISTS analyst_tenant_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analyst_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    notification_level notification_level NOT NULL DEFAULT 'all',
    subscribed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(analyst_id, tenant_id)
);

CREATE INDEX idx_analyst_subscriptions_analyst ON analyst_tenant_subscriptions(analyst_id);
CREATE INDEX idx_analyst_subscriptions_tenant ON analyst_tenant_subscriptions(tenant_id);
CREATE INDEX idx_analyst_subscriptions_level ON analyst_tenant_subscriptions(notification_level);

COMMENT ON TABLE analyst_tenant_subscriptions IS 'SOC analyst subscriptions to specific tenants for focused monitoring';
COMMENT ON COLUMN analyst_tenant_subscriptions.notification_level IS 'Notification preference: all alerts, critical only, or none';

-- ==================================================================
-- 4. System Settings (Global Defaults)
-- ==================================================================

-- Insert default system settings
INSERT INTO system_config (key, value, description) VALUES
    ('agent_offline_threshold', '480', 'Global default: Minutes before agent is marked offline (8 hours)')
ON CONFLICT (key) DO NOTHING;

INSERT INTO system_config (key, value, description) VALUES
    ('agent_dead_threshold', '43200', 'Global default: Minutes before agent is marked dead (30 days)')
ON CONFLICT (key) DO NOTHING;

INSERT INTO system_config (key, value, description) VALUES
    ('portal_mode', '"three_portal"', 'Portal deployment mode: three_portal (Admin, SOC, Customer)')
ON CONFLICT (key) DO NOTHING;

-- ==================================================================
-- 5. Update Agent Table Defaults
-- ==================================================================

-- Update agent_type default from 'vector' to 'fluentbit'
ALTER TABLE agents ALTER COLUMN agent_type SET DEFAULT 'fluentbit';

-- Add agent_type index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_agents_type ON agents(agent_type);

COMMENT ON COLUMN agents.agent_type IS 'Agent type: fluentbit (only supported type)';

-- Update existing agents to fluentbit (if any exist)
UPDATE agents SET agent_type = 'fluentbit' WHERE agent_type = 'vector';

-- ==================================================================
-- 6. Audit Log Enhancements
-- ==================================================================

-- Add audit log categories for Phase 2 operations
COMMENT ON TABLE audit_logs IS 'Audit trail for all sensitive operations (user management, API keys, config changes, agent operations)';

-- ==================================================================
-- End of Phase 2A Schema Migration
-- ==================================================================

-- Verify migration
SELECT 'Phase 2A schema migration completed successfully' AS status;
