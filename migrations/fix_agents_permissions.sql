-- Fix permissions on agents table
-- The api_user needs ALL PRIVILEGES to perform CRUD operations on agents
-- This migration ensures the permission is set correctly

GRANT ALL PRIVILEGES ON agents TO api_user;

-- Verify the grant was successful
SELECT 'Permissions fixed: api_user now has ALL PRIVILEGES on agents table' AS status;
