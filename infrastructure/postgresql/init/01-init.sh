#!/bin/bash
set -e

###############################################################################
# PostgreSQL Initialization Script for O.A.S.I.S.
# Creates database schema and service-specific users
###############################################################################

echo "========================================"
echo "O.A.S.I.S. PostgreSQL Initialization"
echo "========================================"

# Create service-specific users with least privilege
echo "Creating service-specific users..."

# Gateway user (needs to validate API keys)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER gateway_user WITH PASSWORD '${POSTGRES_GATEWAY_PASSWORD:-changeme}';
EOSQL

# Ingestion user (needs to check tenant configuration)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER ingestion_user WITH PASSWORD '${POSTGRES_INGESTION_PASSWORD:-changeme}';
EOSQL

# API user (needs full CRUD access)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER api_user WITH PASSWORD '${POSTGRES_API_PASSWORD:-changeme}';
EOSQL

echo "Service users created successfully"

# Create schema
echo "Creating database schema..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable UUID extension
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    -- Tenants table
    CREATE TABLE IF NOT EXISTS tenants (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name VARCHAR(255) NOT NULL UNIQUE,
        description TEXT,
        eps_limit INTEGER NOT NULL DEFAULT 1000,
        retention_days INTEGER NOT NULL DEFAULT 90,
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

    -- API keys table
    CREATE TABLE IF NOT EXISTS api_keys (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
        key_hash TEXT NOT NULL UNIQUE,
        key_prefix VARCHAR(16) NOT NULL,
        description TEXT,
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        last_used_at TIMESTAMP WITH TIME ZONE,
        expires_at TIMESTAMP WITH TIME ZONE
    );

    CREATE INDEX idx_api_keys_tenant_id ON api_keys(tenant_id);
    CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);

    -- Users table
    CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
        username VARCHAR(255) NOT NULL UNIQUE,
        email VARCHAR(255) NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        totp_secret TEXT,
        role VARCHAR(50) NOT NULL DEFAULT 'tenant_user',
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        last_login_at TIMESTAMP WITH TIME ZONE
    );

    CREATE INDEX idx_users_tenant_id ON users(tenant_id);
    CREATE INDEX idx_users_username ON users(username);
    CREATE INDEX idx_users_email ON users(email);

    -- Certificates table
    CREATE TABLE IF NOT EXISTS certificates (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name VARCHAR(255) NOT NULL UNIQUE,
        certificate_pem TEXT NOT NULL,
        private_key_pem TEXT NOT NULL,
        ca_certificate_pem TEXT,
        description TEXT,
        expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

    CREATE INDEX idx_certificates_name ON certificates(name);
    CREATE INDEX idx_certificates_expires_at ON certificates(expires_at);

    -- Audit logs table
    CREATE TABLE IF NOT EXISTS audit_logs (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        user_id UUID REFERENCES users(id) ON DELETE SET NULL,
        tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
        action VARCHAR(100) NOT NULL,
        resource_type VARCHAR(100) NOT NULL,
        resource_id TEXT,
        details JSONB,
        ip_address INET,
        user_agent TEXT,
        status VARCHAR(50) NOT NULL DEFAULT 'success'
    );

    CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
    CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
    CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
    CREATE INDEX idx_audit_logs_action ON audit_logs(action);
    CREATE INDEX idx_audit_logs_resource_type ON audit_logs(resource_type);

    -- System configuration table
    CREATE TABLE IF NOT EXISTS system_config (
        key VARCHAR(255) PRIMARY KEY,
        value JSONB NOT NULL,
        description TEXT,
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        updated_by UUID REFERENCES users(id) ON DELETE SET NULL
    );

    -- Trigger for updated_at columns
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS \$\$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    \$\$ language 'plpgsql';

    CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

    CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

    CREATE TRIGGER update_certificates_updated_at BEFORE UPDATE ON certificates
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

    CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

EOSQL

echo "Database schema created successfully"

# Grant permissions
echo "Granting permissions..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Gateway user permissions (read-only for api_keys and tenants)
    GRANT SELECT ON tenants TO gateway_user;
    GRANT SELECT ON api_keys TO gateway_user;
    GRANT UPDATE (last_used_at) ON api_keys TO gateway_user;

    -- Ingestion user permissions (read-only for tenants)
    GRANT SELECT ON tenants TO ingestion_user;

    -- API user permissions (full CRUD)
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO api_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO api_user;
EOSQL

echo "Permissions granted successfully"

# Create "Internal" tenant (for SOC operators)
echo "Creating Internal tenant..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    INSERT INTO tenants (id, name, description, eps_limit, retention_days, is_active)
    VALUES (
        'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
        'Internal',
        'Internal SOC team tenant',
        100000,
        365,
        true
    )
    ON CONFLICT (name) DO NOTHING;
EOSQL

echo "Internal tenant created successfully"

# Create default super_admin user
echo "Creating default super_admin user..."

# Default password: Admin123! (bcrypt hash)
# IMPORTANT: Change this password immediately after first login
DEFAULT_PASSWORD_HASH='$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5/d7rg9QCXW9i'

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    INSERT INTO users (id, tenant_id, username, email, password_hash, role, is_active)
    VALUES (
        uuid_generate_v4(),
        'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
        'admin',
        'admin@oasis.local',
        '${DEFAULT_PASSWORD_HASH}',
        'super_admin',
        true
    )
    ON CONFLICT (username) DO NOTHING;
EOSQL

echo "Default super_admin user created (username: admin, password: Admin123!)"
echo "IMPORTANT: Change the default password immediately!"

echo "========================================"
echo "PostgreSQL initialization completed!"
echo "========================================"
