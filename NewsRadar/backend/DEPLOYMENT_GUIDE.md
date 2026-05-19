# NewsRadar Production Deployment Guide

## Quick Start - Local Development

### 1. Setup Environment

```bash
cd NewsRadar/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create or update `.env`:
```bash
# Required - Change these!
JWT_SECRET=your-super-secret-key-change-me-production
ADMIN_EMAIL=admin@yourdomain.com

# API Keys
NEWSAPI_KEY=your_newsapi_key
GROQ_API_KEY=your_groq_api_key

# Email (choose one)
SENDGRID_API_KEY=your_sendgrid_key
# OR
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# App URL
APP_URL=http://localhost:3000
```

### 3. Initialize Database

```bash
python -c "
from db.database import engine
from db.models import Base
from db.seed import seed_db
from db.database import SessionLocal

Base.metadata.create_all(bind=engine)
db = SessionLocal()
seed_db(db)
db.close()
print('Database initialized!')
"
```

### 4. Run Server

```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server will be available at: http://localhost:8000
- API Docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## Default Credentials (Change Immediately!)

```
Email: admin@newsradar.local
Password: Admin@123456
```

**IMPORTANT**: Change admin password after first login!

---

## Production Deployment

### Option 1: Docker Deployment

Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run:
```bash
docker build -t newsradar-backend .
docker run -p 8000:8000 --env-file .env.production newsradar-backend
```

### Option 2: Systemd Service (Linux)

Create `/etc/systemd/system/newsradar.service`:
```ini
[Unit]
Description=NewsRadar API Service
After=network.target

[Service]
Type=simple
User=newsradar
WorkingDirectory=/opt/newsradar/backend
Environment="PATH=/opt/newsradar/venv/bin"
ExecStart=/opt/newsradar/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Start service:
```bash
sudo systemctl start newsradar
sudo systemctl enable newsradar
```

### Option 3: Gunicorn + Nginx

Install Gunicorn:
```bash
pip install gunicorn
```

Run with Gunicorn:
```bash
gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000
```

Nginx reverse proxy (production):
```nginx
upstream newsradar {
    server 127.0.0.1:8000;
}

server {
    listen 443 ssl http2;
    server_name api.newsradar.com;

    ssl_certificate /etc/ssl/certs/newsradar.crt;
    ssl_certificate_key /etc/ssl/private/newsradar.key;

    location / {
        proxy_pass http://newsradar;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Database Migration to PostgreSQL

### 1. Install PostgreSQL adapter
```bash
pip install psycopg2-binary
```

### 2. Create PostgreSQL database
```bash
createdb newsradar
```

### 3. Update .env
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/newsradar
```

### 4. Migrate data (if existing SQLite)
```bash
# Export from SQLite
sqlite3 newsradar.db ".dump" > dump.sql

# Import to PostgreSQL
psql newsradar < dump.sql
```

---

## Email Configuration

### SendGrid Setup (Recommended for Production)

1. Create SendGrid account: https://sendgrid.com
2. Generate API key in Settings → API Keys
3. Set in .env:
```bash
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=noreply@newsradar.com
SENDGRID_FROM_NAME=NewsRadar Team
```

### Gmail Setup (For Testing/Small Scale)

1. Enable "Less secure apps" or use App Passwords
2. Generate App Password: https://myaccount.google.com/apppasswords
3. Set in .env:
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

---

## Admin First-Time Setup

### 1. Change Admin Password

```bash
# Login with default credentials
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@newsradar.local",
    "password": "Admin@123456"
  }'
```

Store the JWT token, then request password reset:
```bash
curl -X POST http://localhost:8000/api/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@newsradar.local"
  }'
```

Check email for reset link and click to reset password.

### 2. Configure Email Service

Update email settings:
```bash
# Verify email sending is working
curl -X POST http://localhost:8000/api/v1/admin/test-email \
  -H "Authorization: Bearer YOUR_ADMIN_JWT_TOKEN"
```

### 3. Add News Sources

```bash
curl -X POST http://localhost:8000/api/v1/admin/sources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ADMIN_JWT_TOKEN" \
  -d '{
    "name": "BBC News",
    "url": "https://feeds.bbc.co.uk/news/rss.xml",
    "source_type": "RSS",
    "reliability": 0.95,
    "is_active": true
  }'
```

### 4. Invite Team Members

```bash
curl -X POST http://localhost:8000/api/v1/admin/users/invite \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ADMIN_JWT_TOKEN" \
  -d '{
    "full_name": "Jane Editor",
    "email": "jane@newsradar.com",
    "role": "editor"
  }'
```

They'll receive an email with an invitation link to join.

### 5. Create Alert Rules

```bash
curl -X POST http://localhost:8000/api/v1/alerts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer EDITOR_JWT_TOKEN" \
  -d '{
    "title": "High Misinformation Risk",
    "description": "Alert when article has high misinformation probability",
    "condition": "misinformation_probability > 0.7",
    "is_urgent": true,
    "is_active": true
  }'
```

---

## Monitoring & Logging

### View Logs

```bash
# SQLite (on-disk)
tail -f newsradar.db.log

# PostgreSQL (database)
SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 100;
```

### Check Email Delivery

```bash
SELECT * FROM email_logs WHERE status = 'failed' ORDER BY sent_at DESC;
```

### Monitor Action Execution

```bash
SELECT user_id, action_type, status, COUNT(*) 
FROM action_executions 
GROUP BY user_id, action_type, status
ORDER BY COUNT(*) DESC;
```

---

## Backup & Recovery

### Backup Database

SQLite:
```bash
cp newsradar.db newsradar.db.backup.$(date +%s)
```

PostgreSQL:
```bash
pg_dump newsradar > newsradar_backup.sql
```

### Restore Database

PostgreSQL:
```bash
psql newsradar < newsradar_backup.sql
```

---

## Performance Optimization

### Database Indexing

Add missing indexes for better performance:
```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_user_invitations_email ON user_invitations(email);
CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_chat_messages_session_id ON chat_messages(session_id);
```

### Connection Pooling

Update `core/config.py` to use connection pool:
```python
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,
)
```

### Caching

Add Redis for session caching:
```python
import redis
cache = redis.Redis(host='localhost', port=6379, db=0)
```

---

## Security Hardening

### Production Checklist

- [ ] Update all default passwords
- [ ] Change JWT_SECRET
- [ ] Configure CORS properly (not "*")
- [ ] Enable HTTPS/TLS
- [ ] Set secure HTTP headers
- [ ] Enable rate limiting
- [ ] Regular security audits
- [ ] Keep dependencies updated
- [ ] Enable audit logging
- [ ] Setup intrusion detection

### Add Rate Limiting

Install SlowAPI:
```bash
pip install slowapi
```

Use in FastAPI:
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/api/v1/auth/login")
@limiter.limit("5/minute")
async def login(req: LoginRequest):
    pass
```

### Add Security Headers

```python
from fastapi.middleware import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://newsradar.yourdomain.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["*"],
)

@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000"
    return response
```

---

## Troubleshooting

### Issue: "ModuleNotFoundError: No module named 'email_service'"

Solution:
```bash
pip install -r requirements.txt
# Make sure __init__.py exists in services/ directory
touch services/__init__.py
```

### Issue: Email not sending

Check configuration:
```python
from services.email_service import email_service
print(f"SendGrid API Key: {email_service.sendgrid_key}")
print(f"SMTP User: {email_service.smtp_user}")
```

### Issue: JWT token always expires

Change `JWT_EXPIRE_MINUTES` in `.env`:
```bash
JWT_EXPIRE_MINUTES=10080  # 7 days
```

### Issue: Database locked (SQLite)

Switch to PostgreSQL for better concurrency.

---

## Support

For issues, check:
1. API_DOCUMENTATION.md for endpoint reference
2. logs/debug output
3. Database audit_logs table
4. email_logs table for email failures
5. GitHub issues

---

## License

NewsRadar © 2024. All rights reserved.
