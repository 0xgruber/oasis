#!/bin/bash
set -e

###############################################################################
# PostgreSQL Migration: Add Agents Table
# Tracks log collection agents (Fluent Bit, Filebeat, etc.) per tenant
###############################################################################

echo "========================================"
echo "Creating agents table..."
echo "========================================"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Agents table (tracks log collection agents)
    CREATE TABLE IF NOT EXISTS agents (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
        hostname VARCHAR(255) NOT NULL,
        agent_type VARCHAR(50) NOT NULL DEFAULT 'fluent-bit',
        os_type VARCHAR(50) NOT NULL,
        os_version VARCHAR(100),
        agent_version VARCHAR(50),
        first_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        ip_address INET,
        metadata JSONB DEFAULT '{}'::jsonb,
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        UNIQUE(tenant_id, hostname)
    );

    -- Indexes for efficient queries
    CREATE INDEX IF NOT EXISTS idx_agents_tenant_id ON agents(tenant_id);
    CREATE INDEX IF NOT EXISTS idx_agents_hostname ON agents(hostname);
    CREATE INDEX IF NOT EXISTS idx_agents_last_seen ON agents(last_seen);
    CREATE INDEX IF NOT EXISTS idx_agents_is_active ON agents(is_active);
    CREATE INDEX IF NOT EXISTS idx_agents_tenant_active ON agents(tenant_id, is_active);

    -- Trigger for updated_at column
    CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON agents
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

    -- Function to automatically mark agents as inactive if not seen recently
    CREATE OR REPLACE FUNCTION mark_inactive_agents()
    RETURNS void AS \$\$
    BEGIN
        UPDATE agents
        SET is_active = false
        WHERE last_seen < NOW() - INTERVAL '15 minutes'
        AND is_active = true;
    END;
    \$\$ language 'plpgsql';

    -- Create a helper function for upserting agent info (used by registration endpoint)
    CREATE OR REPLACE FUNCTION upsert_agent(
        p_tenant_id UUID,
        p_hostname VARCHAR,
        p_agent_type VARCHAR,
        p_os_type VARCHAR,
        p_os_version VARCHAR,
        p_agent_version VARCHAR,
        p_ip_address INET,
        p_metadata JSONB
    )
    RETURNS UUID AS \$\$
    DECLARE
        v_agent_id UUID;
    BEGIN
        INSERT INTO agents (
            tenant_id,
            hostname,
            agent_type,
            os_type,
            os_version,
            agent_version,
            ip_address,
            metadata,
            first_seen,
            last_seen,
            is_active
        ) VALUES (
            p_tenant_id,
            p_hostname,
            p_agent_type,
            p_os_type,
            p_os_version,
            p_agent_version,
            p_ip_address,
            p_metadata,
            NOW(),
            NOW(),
            true
        )
        ON CONFLICT (tenant_id, hostname) 
        DO UPDATE SET
            last_seen = NOW(),
            is_active = true,
            os_version = COALESCE(p_os_version, agents.os_version),
            agent_version = COALESCE(p_agent_version, agents.agent_version),
            ip_address = COALESCE(p_ip_address, agents.ip_address),
            metadata = COALESCE(p_metadata, agents.metadata),
            updated_at = NOW()
        RETURNING id INTO v_agent_id;

        RETURN v_agent_id;
    END;
    \$\$ language 'plpgsql';

EOSQL

echo "Agents table created successfully"

# Grant permissions
echo "Granting permissions on agents table..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Gateway user needs to register agents and update last_seen
    GRANT SELECT, INSERT, UPDATE ON agents TO gateway_user;

    -- API user gets full access
    GRANT ALL PRIVILEGES ON agents TO api_user;

    -- Ingestion user can read agent info if needed
    GRANT SELECT ON agents TO ingestion_user;
EOSQL

echo "Permissions granted successfully"

echo "========================================"
echo "Agents table migration completed!"
echo "========================================"
