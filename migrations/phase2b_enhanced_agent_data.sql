#!/bin/bash
set -e

###############################################################################
# PostgreSQL Migration: Phase 2B - Enhanced Agent Data Collection
# Adds columns for system architecture, kernel version, MAC addresses, and network interfaces
###############################################################################

echo "========================================"
echo "Phase 2B: Adding enhanced agent data columns..."
echo "========================================"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Add new columns to agents table for enhanced system information
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS architecture VARCHAR(50);
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS kernel_version VARCHAR(100);
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS mac_addresses TEXT;
    ALTER TABLE agents ADD COLUMN IF NOT EXISTS network_interfaces TEXT;

    -- Update the upsert_agent function to handle new columns
    CREATE OR REPLACE FUNCTION upsert_agent(
        p_tenant_id UUID,
        p_hostname VARCHAR,
        p_agent_type VARCHAR,
        p_os_type VARCHAR,
        p_os_version VARCHAR,
        p_agent_version VARCHAR,
        p_ip_address INET,
        p_metadata JSONB,
        p_architecture VARCHAR,
        p_kernel_version VARCHAR,
        p_mac_addresses TEXT,
        p_network_interfaces TEXT
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
            architecture,
            kernel_version,
            mac_addresses,
            network_interfaces,
            first_seen,
            last_seen,
            is_active,
            created_at,
            updated_at
        )
        VALUES (
            p_tenant_id,
            p_hostname,
            p_agent_type,
            p_os_type,
            p_os_version,
            p_agent_version,
            p_ip_address,
            COALESCE(p_metadata, '{}'::jsonb),
            p_architecture,
            p_kernel_version,
            p_mac_addresses,
            p_network_interfaces,
            NOW(),
            NOW(),
            true,
            NOW(),
            NOW()
        )
        ON CONFLICT (tenant_id, hostname)
        DO UPDATE SET
            last_seen = NOW(),
            is_active = true,
            os_version = COALESCE(p_os_version, agents.os_version),
            agent_version = COALESCE(p_agent_version, agents.agent_version),
            ip_address = COALESCE(p_ip_address, agents.ip_address),
            metadata = COALESCE(p_metadata, agents.metadata),
            architecture = COALESCE(p_architecture, agents.architecture),
            kernel_version = COALESCE(p_kernel_version, agents.kernel_version),
            mac_addresses = COALESCE(p_mac_addresses, agents.mac_addresses),
            network_interfaces = COALESCE(p_network_interfaces, agents.network_interfaces),
            updated_at = NOW()
        RETURNING id INTO v_agent_id;

        RETURN v_agent_id;
    END;
    \$\$ language 'plpgsql';

    -- Add comment to explain the new columns
    COMMENT ON COLUMN agents.architecture IS 'System architecture (e.g., x86_64 (64-bit), ARM64)';
    COMMENT ON COLUMN agents.kernel_version IS 'Linux kernel version (Linux systems only)';
    COMMENT ON COLUMN agents.mac_addresses IS 'Semicolon-separated MAC addresses with interface names';
    COMMENT ON COLUMN agents.network_interfaces IS 'Comma-separated network interface names';

EOSQL

echo "Phase 2B: Enhanced agent data columns added successfully"

echo "========================================"
echo "Phase 2B migration completed!"
echo "========================================"
