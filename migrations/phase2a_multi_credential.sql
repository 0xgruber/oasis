-- Phase 2A: Multi-Credential RBAC Schema Migration
-- Implements separate credentials per portal with exclusive access

-- ==================================================================
-- 1. Create Credentials Table and Types
-- ==================================================================

-- Create credential type enum
CREATE TYPE credential_type AS ENUM ('soc_analyst', 'platform_admin', 'customer_user');

-- Grant type usage to api_user
GRANT USAGE ON TYPE credential_type TO api_user;

-- Create credentials table
CREATE TABLE credentials (
    credential_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    credential_type credential_type NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    
    -- Constraint: One credential per type per user
    UNIQUE(user_id, credential_type)
);

-- Indexes for performance
CREATE INDEX idx_credentials_username ON credentials(username);
CREATE INDEX idx_credentials_user_id ON credentials(user_id);
CREATE INDEX idx_credentials_type ON credentials(credential_type);
CREATE INDEX idx_credentials_active ON credentials(is_active);
CREATE INDEX idx_credentials_last_used ON credentials(last_used_at);

-- Grant permissions to api_user
GRANT ALL PRIVILEGES ON TABLE credentials TO api_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_user;

-- Trigger for updated_at
CREATE TRIGGER update_credentials_updated_at
    BEFORE UPDATE ON credentials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE credentials IS 'Authentication credentials - each user can have multiple credentials for different portals';
COMMENT ON COLUMN credentials.credential_type IS 'Portal access type: soc_analyst (SOC portal only), platform_admin (admin portal only), customer_user (customer portal only)';
COMMENT ON COLUMN credentials.username IS 'Login username with role suffix (e.g., user.soc, user.admin)';

-- ==================================================================
-- 2. Update Users Table
-- ==================================================================

-- Add full_name column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name VARCHAR(255);

-- Ensure primary user email is populated
UPDATE users 
SET email = 'admin@oasis.local' 
WHERE username = 'admin' AND (email IS NULL OR email = '');

-- ==================================================================
-- 3. Migrate Existing Admin User to Multi-Credential System
-- ==================================================================

-- Step 1: Update the admin user record
UPDATE users 
SET 
    full_name = 'System Administrator',
    email = 'admin@oasis.local'
WHERE username = 'admin';

-- Step 2: Create platform_admin credential (user.admin)
INSERT INTO credentials (user_id, username, password_hash, credential_type)
SELECT 
    id,
    'user.admin',
    password_hash,
    'platform_admin'::credential_type
FROM users 
WHERE username = 'admin'
ON CONFLICT (username) DO NOTHING;

-- Step 3: Create soc_analyst credential (user.soc) for same user
-- Using same password hash as admin for development convenience
INSERT INTO credentials (user_id, username, password_hash, credential_type)
SELECT 
    id,
    'user.soc',
    password_hash,
    'soc_analyst'::credential_type
FROM users 
WHERE username = 'admin'
ON CONFLICT (username) DO NOTHING;

-- Step 4: Clean up test users (these were created during Phase 2A testing)
DELETE FROM users WHERE username IN ('analyst', 'testuser', 'nonadmin');

-- ==================================================================
-- 4. Verification Queries
-- ==================================================================

-- Verify migration success
SELECT 'Phase 2A Multi-Credential Migration Completed' AS status;

-- Show created credentials
SELECT 
    u.email,
    u.full_name,
    c.username,
    c.credential_type,
    c.is_active,
    c.created_at
FROM users u
JOIN credentials c ON u.id = c.user_id
ORDER BY c.credential_type;

-- Expected output:
-- admin@oasis.local | System Administrator | user.admin | platform_admin | true | <timestamp>
-- admin@oasis.local | System Administrator | user.soc   | soc_analyst    | true | <timestamp>

-- Show table counts
SELECT 
    (SELECT COUNT(*) FROM users) AS users_count,
    (SELECT COUNT(*) FROM credentials) AS credentials_count;
-- Expected: users_count=1, credentials_count=2
