-- Migration: Grant ingestion_user permissions on agents table
-- Purpose: Allow ingestion service to update agent heartbeats (last_seen timestamp)
-- Date: 2026-01-11
-- Author: Agent Heartbeat Feature (Phase 2B)

-- Grant SELECT and UPDATE permissions on agents table
GRANT SELECT, UPDATE ON agents TO ingestion_user;

-- Verify permissions
\dp agents
