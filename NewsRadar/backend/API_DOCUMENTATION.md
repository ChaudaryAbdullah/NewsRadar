# NewsRadar Production API Documentation

## Overview
NewsRadar is a production-ready AI-powered news intelligence platform with complete authentication, authorization, audit logging, and action execution tracking.

## Key Features Implemented

### 1. User Management
- **Email Verification**: Users must verify their email before account activation
- **Password Security**: Minimum 8 characters with uppercase and digits
- **Password Reset**: Secure token-based password reset flow
- **Multi-Factor Authentication (MFA)**: TOTP-based 2FA with backup codes
- **Role-Based Access Control (RBAC)**: admin, editor, journalist, consumer, auditor
- **Account Status Tracking**: pending, active, locked, archived

### 2. User Invitations
- Admin can invite users via email
- Invitation tokens expire in 72 hours (configurable)
- Invitations create audit trail
- Email sent to invitee with acceptance link

### 3. Authentication Endpoints

#### POST `/api/v1/auth/register`
Create account with email verification
```json
{
  "full_name": "John Doe",
  "email": "john@example.com",
  "password": "SecurePass123",
  "role": "consumer"
}
```
Response: JWT token (valid 15 min) + user profile

#### POST `/api/v1/auth/login`
Authenticate user
```json
{
  "email": "john@example.com",
  "password": "SecurePass123",
  "mfa_token": "123456"  // Only if MFA enabled
}
```
Response: JWT token (valid 7 days) + user profile

#### POST `/api/v1/auth/verify-email`
Verify email with token from email
```json
{
  "token": "verification_token_from_email"
}
```

#### POST `/api/v1/auth/forgot-password`
Request password reset
```json
{
  "email": "john@example.com"
}
```
Email sent with reset link

#### POST `/api/v1/auth/reset-password`
Reset password with token
```json
{
  "token": "reset_token_from_email",
  "new_password": "NewSecure123"
}
```

#### POST `/api/v1/auth/setup-mfa`
Get MFA setup QR code
Response: Base64 QR code image + secret + backup codes

#### POST `/api/v1/auth/verify-mfa`
Enable MFA after scanning QR code
```json
{
  "token": "123456"  // TOTP code from authenticator
}
```

#### GET `/api/v1/auth/me`
Get current user profile (requires JWT token)

---

## 4. Admin User Management

### POST `/api/v1/admin/users/invite`
Send invitation to new user (admin only)
```json
{
  "full_name": "Jane Smith",
  "email": "jane@example.com",
  "role": "editor"
}
```
Response: Invitation object with token

### POST `/api/v1/admin/users/invitations/accept`
Accept invitation and create account
```json
{
  "token": "invitation_token",
  "password": "SecurePass123"
}
```
Response: User profile

### GET `/api/v1/admin/users`
List all users with filters
- `?skip=0&limit=50`
- `?role=editor`
- `?status=active`

### GET `/api/v1/admin/users/invitations`
List all sent invitations
- `?status=pending`

### PATCH `/api/v1/admin/users/{user_id}/role`
Change user role (admin only)
```json
{
  "role": "editor"
}
```

### PATCH `/api/v1/admin/users/{user_id}/status`
Lock/unlock user account (admin only)
```json
{
  "status": "locked"  // or "active", "archived"
}
```

### DELETE `/api/v1/admin/users/{user_id}`
Delete user (admin only)

---

## 5. Alert Rules Management

### GET `/api/v1/alerts`
List all alert rules
- `?include_inactive=false`
Response includes `subscribed: true/false` for current user

### POST `/api/v1/alerts`
Create alert rule (editor+ role required)
```json
{
  "title": "Misinformation Detection",
  "description": "Alert when misinformation probability exceeds threshold",
  "condition": "misinformation_pct > 30",
  "is_urgent": true,
  "is_active": true
}
```

### PATCH `/api/v1/alerts/{alert_id}`
Update alert rule (creator or admin only)
```json
{
  "title": "Updated Title",
  "is_active": false
}
```

### DELETE `/api/v1/alerts/{alert_id}`
Delete alert rule (admin only)

### POST `/api/v1/alerts/{alert_id}/subscribe`
Subscribe to alert notifications
```json
{
  "delivery_method": "email"  // in_app, email, webhook
}
```

### DELETE `/api/v1/alerts/{alert_id}/subscribe`
Unsubscribe from alert

---

## 6. News Sources Management

### GET `/api/v1/admin/sources`
List all news sources (admin only)

### POST `/api/v1/admin/sources`
Add new source (admin only)
```json
{
  "name": "BBC News",
  "url": "https://feeds.bbc.co.uk/news/rss.xml",
  "source_type": "RSS",
  "reliability": 0.92,
  "is_active": true
}
```

### PATCH `/api/v1/admin/sources/{source_id}`
Update source (admin only)
```json
{
  "reliability": 0.95,
  "is_active": true
}
```

### DELETE `/api/v1/admin/sources/{source_id}`
Delete source (admin only)

---

## 7. Article Analysis

### POST `/api/v1/analysis/analyze`
Run full agent pipeline on article
```json
{
  "id": "article-1",
  "title": "Article Title",
  "description": "Short description",
  "content": "Full article content",
  "url": "https://example.com/article",
  "published_at": "2024-05-19T10:00:00Z",
  "source": {
    "id": "src-bbc",
    "name": "BBC News"
  }
}
```
Response: Analysis with insights, evaluation, recommended actions, trace

### POST `/api/v1/analysis/simulate`
Simulate action execution (real state changes tracked)
```json
{
  "article_id": "article-1",
  "action_type": "FACT_CHECK",
  "source_id": "src-bbc"
}
```
Response: Before/after state snapshots

---

## 8. Audit Logging

All actions are logged to `audit_logs` table:
- User authentication (login, register, email verify, password reset)
- User management (role changes, status changes, invitations)
- Alert management (create, update, delete, subscribe)
- Source management (add, update, delete)
- Action execution (fact check, alert, quarantine, etc.)

Query example:
```sql
SELECT * FROM audit_logs 
WHERE user_id = 'usr-123' 
AND action = 'USER_LOGIN'
ORDER BY created_at DESC
```

---

## 9. Database Models

### User
- Tracks email verification, MFA status, password reset tokens
- Stores user preferences as JSON
- Relations: audit_logs, action_executions, chat_messages, alerts

### UserInvitation
- Tracks pending and accepted invitations
- Includes expiry time and token
- Full audit trail of who invited whom

### ActionExecution
- Tracks every action execution with before/after snapshots
- Records execution status (pending, in_progress, completed, failed)
- Stores JSON state objects for comparison

### ChatMessage
- Persists conversation history per user/session
- Stores article context and sources for each message

### AlertRule & UserAlert
- Alert rules created by editors
- User subscriptions with delivery preferences
- Separate tracking for each user's subscriptions

### SystemConfig
- Dynamic system configuration (replaces hardcoded values)
- Admin can update settings without code changes

---

## 10. Production Setup Checklist

### Security
- [ ] Change JWT_SECRET in .env (currently: "newsradar-production-secret-key-2024-change-me")
- [ ] Change default admin password (currently: admin@newsradar.local / Admin@123456)
- [ ] Configure email service (SendGrid or SMTP)
- [ ] Use HTTPS in production
- [ ] Set appropriate CORS origins
- [ ] Enable MFA for admin and editor roles

### Email Configuration
Set in .env:
```
SENDGRID_API_KEY=your_key_here
SENDGRID_FROM_EMAIL=noreply@yourcompany.com

# OR for SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password
```

### Database
- Use PostgreSQL instead of SQLite in production
- Set `DATABASE_URL=postgresql://user:pass@host:5432/newsradar`
- Run migrations: `alembic upgrade head`

### Environment Variables
```bash
# Core
JWT_SECRET=<strong_secret>
DATABASE_URL=postgresql://...
DEBUG=false

# APIs
NEWSAPI_KEY=<your_key>
GROQ_API_KEY=<your_key>

# Email
SENDGRID_API_KEY=<your_key>
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<email>
SMTP_PASSWORD=<password>

# App
APP_URL=https://newsradar.yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com
```

### Monitoring
- [ ] Enable structured logging (JSON format)
- [ ] Set up error tracking (Sentry, etc.)
- [ ] Monitor email deliverability
- [ ] Track API response times
- [ ] Monitor database performance

---

## 11. Testing APIs

### Using cURL

#### Register
```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Test User",
    "email": "test@example.com",
    "password": "TestPass123",
    "role": "consumer"
  }'
```

#### Login
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "TestPass123"
  }'
```

#### Get Profile (with JWT token)
```bash
curl -X GET http://localhost:8000/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Invite User (admin only)
```bash
curl -X POST http://localhost:8000/api/v1/admin/users/invite \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN" \
  -d '{
    "full_name": "New User",
    "email": "newuser@example.com",
    "role": "editor"
  }'
```

---

## 12. Error Handling

All errors return standard format:
```json
{
  "detail": "Error message here"
}
```

Common status codes:
- 400: Bad request (validation error)
- 401: Unauthorized (missing/invalid token)
- 403: Forbidden (insufficient permissions)
- 404: Not found
- 409: Conflict (duplicate email, etc.)
- 500: Server error

---

## 13. API Documentation

Interactive API docs available at:
- http://localhost:8000/docs (Swagger UI)
- http://localhost:8000/redoc (ReDoc)

---

## 14. Support & Troubleshooting

### Email not sending?
1. Check email service configuration in .env
2. Verify API keys/credentials
3. Check email_logs table for failure reasons
4. Enable DEBUG=true for detailed logging

### JWT token expired?
1. Register/login to get new token
2. Tokens valid for 7 days by default
3. Change JWT_EXPIRE_MINUTES in .env if needed

### Invitation expired?
1. Admins can send new invitation
2. Default expiry: 72 hours
3. Change DEFAULT_INVITE_EXPIRES_HOURS in .env

### MFA issues?
1. Ensure time is synchronized on server
2. Use authenticator app (Google Authenticator, Authy, etc.)
3. Backup codes can be used if TOTP fails

---

## Architecture Decisions

### Why these technologies?
- **FastAPI**: Modern, fast, with automatic API docs
- **SQLAlchemy**: Powerful ORM with migrations support
- **Groq**: Fast inference for NLP models
- **TOTP MFA**: No external service dependency
- **SendGrid/SMTP**: Flexible email sending options

### Security Best Practices Implemented
- Password hashing with bcrypt
- JWT with expiry and JTI (JWT ID)
- Email verification before account activation
- Secure password reset tokens
- TOTP-based MFA
- Complete audit logging
- Role-based access control
- Rate limiting ready (to be added)
- CORS configured

### Scalability
- Database queries optimized with indexes
- Audit logs for all changes
- Action execution tracking separate from processing
- Chat history persistence ready
- SystemConfig for dynamic settings without redeployment
