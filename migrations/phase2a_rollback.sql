-- Rollback Phase 2A Schema Migration
-- Run this to undo Phase 2A changes

-- Drop tables
DROP TABLE IF EXISTS analyst_tenant_subscriptions CASCADE;
DROP TABLE IF EXISTS tenant_settings CASCADE;

-- Drop types
DROP TYPE IF EXISTS notification_level CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;

-- Restore original users.role column
ALTER TABLE users ALTER COLUMN role TYPE VARCHAR(50);
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'tenant_user';

-- Remove indexes
DROP INDEX IF EXISTS idx_users_role;
DROP INDEX IF EXISTS idx_agents_type;

-- Remove system config entries
DELETE FROM system_config WHERE key IN ('agent_offline_threshold', 'agent_dead_threshold', 'portal_mode');

SELECT 'Phase 2A rollback completed' AS status;
