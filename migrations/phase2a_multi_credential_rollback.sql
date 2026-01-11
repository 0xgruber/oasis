-- Phase 2A Multi-Credential RBAC Rollback Script
-- Reverts database to single-credential system

-- ==================================================================
-- WARNING: This will delete all credentials data
-- ==================================================================

-- Drop credentials table
DROP TABLE IF EXISTS credentials CASCADE;

-- Drop credential type enum
DROP TYPE IF EXISTS credential_type CASCADE;

-- Remove full_name column from users (optional - data preserved if not removed)
-- ALTER TABLE users DROP COLUMN IF EXISTS full_name;

-- Verification
SELECT 'Phase 2A Multi-Credential Rollback Completed' AS status;

-- Note: Original users table data (username, password_hash, role) is preserved
-- The system can fall back to old authentication method
