# 🚀 Production Deployment Checklist

Use this checklist to ensure everything is properly configured before deploying to production.

---

## Phase 1: Pre-Deployment (Local Testing)

### Security Setup
- [ ] Change JWT_SECRET to a strong random value (minimum 32 characters)
  ```bash
  # Generate with: python -c "import secrets; print(secrets.token_urlsafe(32))"
  ```
- [ ] Change admin password from `Admin@123456` to a strong password
- [ ] Review .env and ensure no sensitive data is committed to git
- [ ] Add .env to .gitignore if not already done

### Database Setup
- [ ] Test SQLite locally (current setup)
- [ ] Plan PostgreSQL migration for production
- [ ] Create database migration script for production
- [ ] Test backups and recovery process

### Email Configuration
- [ ] Configure SendGrid (preferred):
  - [ ] Create SendGrid account
  - [ ] Get API key
  - [ ] Verify sender email domain
  - [ ] Set SENDGRID_API_KEY in .env
- [ ] OR configure SMTP fallback:
  - [ ] Setup Gmail with 2FA
  - [ ] Generate app password
  - [ ] Set SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD
- [ ] Test email sending with test@test.com account

### Application Testing
- [ ] Run database initialization: `python db/seed.py`
- [ ] Start server: `python -m uvicorn main:app`
- [ ] Test registration: POST /api/v1/auth/register
- [ ] Test email verification: Click link in test email
- [ ] Test login: POST /api/v1/auth/login
- [ ] Test MFA setup: POST /api/v1/auth/setup-mfa
- [ ] Test admin invitation: POST /api/v1/admin/users/invite
- [ ] Test alert creation: POST /api/v1/alerts
- [ ] Test action execution: POST /api/v1/analysis/execute-action

### Documentation Review
- [ ] Read API_DOCUMENTATION.md for all endpoints
- [ ] Read DEPLOYMENT_GUIDE.md for production setup
- [ ] Review PRODUCTION_FEATURES.md for feature overview

---

## Phase 2: Production Deployment

### Choose Deployment Platform

#### Option A: Docker
- [ ] Install Docker Engine
- [ ] Create Dockerfile (provided in DEPLOYMENT_GUIDE.md)
- [ ] Build image: `docker build -t newsradar:prod .`
- [ ] Setup Docker Compose with PostgreSQL
- [ ] Test locally with Docker
- [ ] Push to Docker registry (Docker Hub, ECR, etc.)

#### Option B: Linux with Systemd
- [ ] SSH to Linux server
- [ ] Install Python 3.9+: `sudo apt update && sudo apt install python3-pip`
- [ ] Install PostgreSQL: `sudo apt install postgresql`
- [ ] Clone repository
- [ ] Create virtual environment
- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Setup systemd service (see DEPLOYMENT_GUIDE.md)
- [ ] Enable service: `sudo systemctl enable newsradar`
- [ ] Start service: `sudo systemctl start newsradar`

#### Option C: Cloud Platform
- [ ] Choose platform (AWS, Google Cloud, Azure, Heroku)
- [ ] Setup database service
- [ ] Setup managed email service
- [ ] Deploy with `git push` or container registry
- [ ] Configure environment variables

### Database Configuration
- [ ] Switch from SQLite to PostgreSQL
- [ ] Update DATABASE_URL in .env
- [ ] Run migrations:
  ```bash
  python -c "
  from db.database import engine
  from db.models import Base
  from db.seed import seed_db
  from sqlalchemy.orm import SessionLocal
  
  Base.metadata.create_all(bind=engine)
  with SessionLocal() as db:
      seed_db(db)
  "
  ```
- [ ] Verify all tables created: `\dt` in psql
- [ ] Create database backups

### Web Server Setup
- [ ] Install Nginx
- [ ] Configure reverse proxy (see DEPLOYMENT_GUIDE.md)
- [ ] Setup SSL/TLS certificate (Let's Encrypt)
- [ ] Configure HTTPS redirect
- [ ] Test SSL: `curl https://yourdomain.com/api/v1/auth/me`

### Security Configuration
- [ ] Enable HTTPS only (disable HTTP)
- [ ] Set CORS origins (not "*"):
  - [ ] Update core/config.py CORS_ORIGINS
  - [ ] Set to your frontend domain only
- [ ] Configure security headers
- [ ] Enable HSTS
- [ ] Setup WAF (Web Application Firewall)
- [ ] Configure rate limiting
- [ ] Setup DDoS protection

### Monitoring & Logging
- [ ] Setup centralized logging (ELK, CloudWatch, etc.)
- [ ] Configure error tracking (Sentry, Rollbar, etc.)
- [ ] Setup performance monitoring (New Relic, DataDog, etc.)
- [ ] Configure uptime monitoring
- [ ] Setup alerts for critical errors

### Email Service Verification
- [ ] Test email verification flow in production
- [ ] Send test invitation email
- [ ] Verify email templates render correctly
- [ ] Check email delivery (SendGrid dashboard)
- [ ] Monitor email logs table

---

## Phase 3: Post-Deployment

### Smoke Tests
- [ ] Access /docs endpoint and see Swagger UI
- [ ] Test registration flow end-to-end
- [ ] Test login with MFA
- [ ] Test admin invitation
- [ ] Test alert creation
- [ ] Check email delivery
- [ ] Verify audit logs are being created

### Database Verification
- [ ] Count users: `SELECT COUNT(*) FROM users;`
- [ ] Check audit logs: `SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 10;`
- [ ] Verify email logs: `SELECT * FROM email_logs ORDER BY created_at DESC LIMIT 10;`
- [ ] Monitor disk usage: `SELECT pg_database_size('newsradar');`

### Backup & Recovery
- [ ] Schedule automated daily backups
- [ ] Test restore from backup
- [ ] Document backup procedure
- [ ] Document recovery procedure

### Monitoring Configuration
- [ ] Configure alerts for:
  - [ ] High error rate (> 1%)
  - [ ] Response time > 1s
  - [ ] Database connection failures
  - [ ] Disk space < 10%
  - [ ] Failed email deliveries
- [ ] Setup on-call rotation
- [ ] Create runbook for common issues

### Final Verification
- [ ] Check SSL certificate validity
- [ ] Verify all API endpoints working
- [ ] Load testing (Apache Bench, wrk)
- [ ] Security scanning (OWASP ZAP)
- [ ] Check database performance
- [ ] Monitor log files for errors

---

## Phase 4: Ongoing Maintenance

### Daily
- [ ] Monitor error logs
- [ ] Check email delivery
- [ ] Verify API response times
- [ ] Monitor database size growth

### Weekly
- [ ] Review audit logs for suspicious activity
- [ ] Check failed login attempts
- [ ] Monitor backup completion
- [ ] Review performance metrics

### Monthly
- [ ] Update dependencies (carefully!)
- [ ] Review and rotate credentials
- [ ] Analyze usage patterns
- [ ] Plan capacity expansion
- [ ] Review security logs

### Quarterly
- [ ] Security audit
- [ ] Database maintenance/optimization
- [ ] Load testing
- [ ] Disaster recovery drill

---

## Critical Production Settings

### .env (Production Values)
```bash
# Security - MUST CHANGE
JWT_SECRET=<strong-random-32-char-string>
DEBUG=false

# Database - MUST CHANGE
DATABASE_URL=postgresql://user:password@host:5432/newsradar

# Email - MUST CONFIGURE
SENDGRID_API_KEY=<your-key>
# OR
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=notifications@yourdomain.com
SMTP_PASSWORD=<app-password>

# Application
APP_URL=https://yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com
CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# Timeouts
JWT_EXPIRE_MINUTES=10080  # 7 days
DEFAULT_INVITE_EXPIRES_HOURS=72
DEFAULT_PASSWORD_RESET_EXPIRES_MINUTES=60
```

### Security Headers (Nginx)
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### Database Backup Script
```bash
#!/bin/bash
# newsradar-backup.sh
BACKUP_DIR="/backups/newsradar"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump newsradar | gzip > $BACKUP_DIR/newsradar_$TIMESTAMP.sql.gz
# Keep only last 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete
```

### Cron Job for Backups
```bash
0 2 * * * /usr/local/bin/newsradar-backup.sh
# Backup at 2 AM daily
```

---

## Troubleshooting Production Issues

### Application won't start
```bash
# Check logs
sudo journalctl -u newsradar -n 100 -f

# Check Python errors
python -m py_compile main.py

# Check imports
python -c "from db.database import engine"
```

### Database connection failing
```bash
# Test connection
psql "postgresql://user:password@host:5432/newsradar"

# Check connection pool
ps aux | grep postgres
```

### Email not sending
```bash
# Check email logs
SELECT * FROM email_logs WHERE status = 'failed' ORDER BY created_at DESC;

# Test SendGrid
curl https://api.sendgrid.com/v3/mail/send

# Test SMTP
python -c "import smtplib; smtplib.SMTP('smtp.gmail.com', 587).quit()"
```

### High response times
```bash
# Check database slow queries
SELECT * FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;

# Monitor CPU/Memory
top -u postgres
```

### Disk space filling up
```bash
# Check largest tables
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 5;

# Archive old logs
DELETE FROM email_logs WHERE created_at < NOW() - INTERVAL '90 days';
DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '90 days';
```

---

## Emergency Procedures

### Account Locked/Compromised
```bash
# Unlock user
UPDATE users SET status = 'active' WHERE email = 'user@example.com';

# Force password reset
UPDATE users SET password_reset_token = '<new-token>', 
                password_reset_expires = NOW() + INTERVAL '1 hour'
WHERE email = 'user@example.com';
```

### Database Corruption
```bash
# Restore from backup
psql newsradar < /backups/newsradar_YYYYMMDD.sql

# Verify integrity
REINDEX DATABASE newsradar;
ANALYZE;
```

### Ransomware/Attack
```bash
1. Take database offline immediately
2. Kill all connections: SELECT pg_terminate_backend(pid) FROM pg_stat_activity;
3. Restore from clean backup
4. Review audit_logs for suspicious activity
5. Investigate and fix vulnerability
6. Bring system back online
```

---

## Success Criteria

You'll know production is properly setup when:

✅ All APIs responding with 200 status codes  
✅ Email verification flow working end-to-end  
✅ MFA setup and verification working  
✅ Admin invitations sending emails and creating users  
✅ Alert rules creating and triggering  
✅ Action executions tracking before/after states  
✅ Audit logs showing all activities  
✅ Database backups running automatically  
✅ Monitoring alerts firing appropriately  
✅ HTTPS certificate valid  
✅ No errors in application logs  

---

## Quick Reference Commands

```bash
# Start server
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# Watch logs (systemd)
sudo journalctl -u newsradar -f

# Check database
psql -d newsradar -c "SELECT COUNT(*) FROM users;"

# Backup database
pg_dump newsradar > /backups/newsradar_backup.sql

# Restore database
psql newsradar < /backups/newsradar_backup.sql

# Test API
curl -X GET http://localhost:8000/api/v1/health

# Generate JWT_SECRET
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Change admin password
# (Use password reset flow, don't modify database directly)
```

---

## Documentation Links

- **API_DOCUMENTATION.md** - All endpoints and examples
- **DEPLOYMENT_GUIDE.md** - Detailed deployment steps
- **PRODUCTION_FEATURES.md** - Feature overview
- **README_PRODUCTION.md** - Quick start guide

---

**Your production deployment is ready! 🚀**

Complete this checklist before going live!
