# O.A.S.I.S. Phase 1A - Testing Guide

## Prerequisites

- Docker and Docker Compose installed
- Ports 3000, 8000, 8443, 8444, 5432, 8123, 9000, 6333 available
- At least 16GB RAM available for all services

## Starting the Stack

### 1. Set Up Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and set secure passwords
nano .env
```

Minimum required variables:
```bash
POSTGRES_ADMIN_PASSWORD=your_secure_password
CLICKHOUSE_ADMIN_PASSWORD=your_secure_password
JWT_SECRET=your_jwt_secret_key
```

### 2. Start All Services

```bash
# Build and start all services
docker compose up -d

# Check service health
docker compose ps

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f soc-portal
docker compose logs -f api-service
```

Expected startup time: 2-3 minutes for all services to become healthy.

### 3. Verify Services Are Running

```bash
# Check service health endpoints
curl http://localhost:8000/health     # API Service
curl http://localhost:3000            # SOC Portal
```

## Testing the Complete Pipeline

### Step 1: Access the SOC Portal

1. Open your browser and navigate to: **http://localhost:3000**
2. You should be redirected to the login page

### Step 2: Login with Default Credentials

```
Username: admin
Password: Admin123!
```

**Expected Result:**
- Successful login
- Redirect to dashboard at http://localhost:3000/dashboard
- JWT token stored in browser cookies
- User information displayed in sidebar (username: admin, role: super_admin)

### Step 3: Explore the Dashboard

The dashboard should display:
- Welcome message with username
- Four stat cards (all showing 0 initially):
  - Total Logs: 0
  - Active Alerts: 0
  - Sources: 0
  - Ingestion Rate: 0/s
- Quick Actions section with three cards
- System Status section showing all services as "operational"

### Step 4: View Logs

1. Click on "Logs" in the sidebar navigation
2. You should see the logs page at http://localhost:3000/dashboard/logs

**Expected Result:**
- Empty table with message "No logs found" (since no logs have been ingested yet)
- Table headers: Timestamp, Severity, Message, Actions
- Pagination controls (disabled when no logs)
- Refresh button

### Step 5: Ingest Test Logs

Now let's send some test logs to verify the complete pipeline works.

#### Option A: Using curl

```bash
# Get your API key (from PostgreSQL)
docker compose exec postgresql psql -U admin -d oasis -c \
  "SELECT api_key FROM api_keys WHERE tenant_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';"

# Send a test log
curl -X POST http://localhost:8443/api/v1/ingest \
  -H "X-API-Key: YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2024-01-08T12:00:00Z",
    "severity": "info",
    "message": "Test log message from curl",
    "source": "test-system",
    "application": "test-app",
    "raw_log": "Test log entry"
  }'
```

#### Option B: Using Vector (Recommended)

1. Copy the Vector example configuration:
```bash
cp VECTOR_EXAMPLES/vector.toml.linux /tmp/vector.toml

# Edit and add your API key
nano /tmp/vector.toml
```

2. Run Vector:
```bash
vector --config /tmp/vector.toml
```

3. Generate test logs:
```bash
# Write to a file that Vector is watching
echo '{"timestamp":"2024-01-08T12:00:00Z","severity":"info","message":"Test from Vector","source":"vector-agent"}' >> /tmp/test.log
```

### Step 6: Verify Logs in Portal

1. Go back to http://localhost:3000/dashboard/logs
2. Click the "Refresh" button
3. You should now see your test logs in the table

**Expected Result:**
- Logs appear in the table with:
  - Timestamp (formatted as YYYY-MM-DD HH:mm:ss)
  - Severity badge (colored: Info = blue, Warning = yellow, Error = red, etc.)
  - Truncated message
  - "View" button
- Total logs count updated at the top
- Pagination works if more than 50 logs

### Step 7: View Log Details

1. Click on any log row or the "View" button
2. A modal should appear with full log details

**Expected Result:**
- Modal displays:
  - UUID (full log identifier)
  - Timestamp (full datetime)
  - Severity (with color)
  - Raw Log (original log text)
  - OCSF Data (normalized JSON structure)
- Can close modal by clicking X or outside the modal

### Step 8: Test Pagination

If you have more than 50 logs:
1. Navigate to page 2 using the "Next" button
2. Verify different logs are displayed
3. Click "Previous" to go back
4. Current page number should be displayed

### Step 9: Logout

1. Click the logout icon (🚪) in the sidebar at the bottom
2. Should be redirected to login page
3. JWT token should be cleared from cookies

### Step 10: Verify Authentication

1. Try to access http://localhost:3000/dashboard directly
2. Should be redirected to http://localhost:3000/login
3. Login again to verify credentials work

## Testing API Endpoints Directly

### Login API

```bash
# Login and get JWT token
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "Admin123!"
  }'

# Response:
# {
#   "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
#   "token_type": "bearer"
# }
```

### Query Logs API

```bash
# Get JWT token from login response above
TOKEN="your_jwt_token_here"

# Query logs
curl -X GET "http://localhost:8000/logs?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN"

# Response:
# {
#   "logs": [...],
#   "total": 5,
#   "offset": 0,
#   "limit": 10
# }
```

## Verifying Database State

### PostgreSQL (Metadata)

```bash
# Connect to PostgreSQL
docker compose exec postgresql psql -U admin -d oasis

# Check tenants
SELECT * FROM tenants;

# Check users
SELECT user_id, username, role, tenant_id FROM users;

# Check API keys (hashed)
SELECT api_key_id, tenant_id, created_at FROM api_keys;

# Exit
\q
```

### ClickHouse (Logs)

```bash
# Connect to ClickHouse
docker compose exec clickhouse clickhouse-client

# Check databases
SHOW DATABASES;

# Use oasis database
USE oasis;

# Check tables (should see logs_ffffffff-ffff-ffff-ffff-ffffffffffff)
SHOW TABLES;

# Query logs
SELECT COUNT(*) FROM `logs_ffffffff-ffff-ffff-ffff-ffffffffffff`;

# View recent logs
SELECT timestamp, severity_id, message, raw_log 
FROM `logs_ffffffff-ffff-ffff-ffff-ffffffffffff` 
ORDER BY timestamp DESC 
LIMIT 10;

# Exit
EXIT;
```

## Performance Testing

### Load Testing with Apache Bench

```bash
# Get API key first
API_KEY="your_api_key_here"

# Prepare test payload
cat > /tmp/test_log.json <<EOF
{
  "timestamp": "2024-01-08T12:00:00Z",
  "severity": "info",
  "message": "Load test log",
  "source": "load-test"
}
EOF

# Run load test (100 requests, 10 concurrent)
ab -n 100 -c 10 \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -p /tmp/test_log.json \
  http://localhost:8443/api/v1/ingest
```

### Expected Performance

- **Ingestion**: 500-1000 logs/second (single gateway instance)
- **Query**: Sub-second response for 50 logs
- **Login**: < 100ms
- **Frontend Load**: < 2 seconds initial load

## Troubleshooting

### Frontend Won't Start

```bash
# Check logs
docker compose logs -f soc-portal

# Common issues:
# - Port 3000 already in use
# - Node modules not installed (restart container)
```

### Can't Login

```bash
# Verify admin user exists
docker compose exec postgresql psql -U admin -d oasis -c \
  "SELECT username, role FROM users WHERE username='admin';"

# Verify password hash (should see bcrypt hash starting with $2b$)
docker compose exec postgresql psql -U admin -d oasis -c \
  "SELECT password_hash FROM users WHERE username='admin';"

# Check API service logs
docker compose logs -f api-service
```

### No Logs Appearing

```bash
# Check if logs reached ClickHouse
docker compose exec clickhouse clickhouse-client \
  --query "SELECT COUNT(*) FROM oasis.\`logs_ffffffff-ffff-ffff-ffff-ffffffffffff\`"

# Check ingestion service logs
docker compose logs -f ingestion-service

# Check gateway logs
docker compose logs -f external-gateway
```

### 401 Unauthorized Errors

```bash
# JWT token may have expired (60 minutes)
# Login again to get a new token

# Verify JWT secret matches between .env and running containers
docker compose exec api-service env | grep JWT_SECRET
```

## Stopping the Stack

```bash
# Stop all services (keeps data)
docker compose stop

# Stop and remove containers (keeps volumes)
docker compose down

# Stop, remove containers, and delete all data
docker compose down -v
```

## Reset Everything

```bash
# Complete reset
docker compose down -v
docker volume prune -f
docker compose up -d
```

Wait 2-3 minutes for services to become healthy, then test again.

## Success Criteria

✅ **Phase 1A Complete** when all of these work:
1. SOC Portal loads at http://localhost:3000
2. Can login with admin/Admin123!
3. Dashboard displays correctly
4. Can submit logs via gateway API (curl or Vector)
5. Logs appear in ClickHouse database
6. Logs appear in SOC Portal logs page
7. Can click on logs to view full details
8. Pagination works
9. Can logout and login again
10. JWT authentication works on API endpoints

## Next Steps

After verifying Phase 1A works:
1. Review `IMPROVEMENTS.md` for Phase 1B/1C/2 features
2. Implement syslog listeners (UDP/TCP/TLS)
3. Add tenant management UI
4. Implement mTLS between services
5. Add real-time metrics dashboard
6. Implement alert management
