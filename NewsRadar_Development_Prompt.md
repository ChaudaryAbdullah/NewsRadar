# NewsRadar — Agent Development Prompt
### AI-Powered News Intelligence & Information Integrity Platform
**IEEE 830 / ISO/IEC/IEEE 29148:2018 Compliant | SRS v1.0**

---

## 🎯 Mission Brief

You are the **lead engineering agent** for **NewsRadar** — an enterprise-grade, AI-powered news intelligence platform that ingests, enriches, fact-checks, and surfaces news from across the internet in real time. Your goal is to deliver a production-ready, fully containerized, event-driven microservices platform from the ground up, following the architecture and requirements described below with zero ambiguity tolerance.

This is not a prototype. Build it like it will serve 100,000 users on day one.

---

## 🏗️ System Overview

**NewsRadar** is a multi-tenant platform that:
1. **Ingests** news articles from RSS feeds, web scrapers, and social media APIs continuously.
2. **Enriches** every article with LLM-powered summarization, Named Entity Recognition (NER), sentiment scoring, topic classification, and vector embeddings.
3. **Fact-checks** every article by extracting verifiable claims and querying IFCN-certified fact-checking APIs, computing per-source reliability scores, and assigning integrity verdicts.
4. **Exposes** all of the above through versioned REST and WebSocket APIs to a React dashboard used by consumers, journalists, editors, admins, and auditors.

---

## 📐 Architecture

**Pattern:** Event-Driven Microservices over Apache Kafka.

All services are independently deployable Docker containers orchestrated on Kubernetes (v1.29+). No service may directly query another service's database. All cross-service data propagation goes through Kafka topics.

### Services to Build

| Service | Language / Framework | Responsibility |
|---|---|---|
| `ingestion-service` | Python 3.11 / FastAPI | RSS fetching, scraping, deduplication (Redis SHA-256), Avro serialization, Kafka publication |
| `nlp-service` | Python 3.11 / FastAPI + Celery | LLM calls (summarization, NER, sentiment, topic classification), embedding generation, vector DB upsert |
| `integrity-service` | Python 3.11 / FastAPI | Claim extraction, fact-check API integration, source reliability scoring, verdict assignment |
| `user-service` | Python 3.11 / FastAPI | User CRUD, JWT issuance (RS256), RBAC, TOTP MFA, audit logging |
| `api-gateway` | Node.js 20 / Fastify | JWT verification, request routing, rate limiting, API versioning |
| `notification-service` | Python 3.11 / Celery Beat | Alert rule evaluation, email dispatch (SendGrid), webhook delivery, digest scheduling |
| `dashboard-service` (BFF) | Node.js 20 / Express | Backend-for-frontend aggregating data for the analytics dashboard |
| `audit-service` | Python 3.11 / FastAPI | Immutable audit log ingestion, GDPR compliance report generation |
| `frontend` | React 18 / TypeScript | Full-featured SPA — news feed, article detail, analytics dashboard, admin panel |

---

## 🗄️ Data Layer

### Storage Technologies

| Store | Version | Purpose |
|---|---|---|
| PostgreSQL | 16+ | Primary relational store — articles, users, sources, verdicts, audit logs, alert rules |
| Redis | 7.x | Deduplication cache, session tokens, rate limit counters, real-time trending cache |
| Elasticsearch | 8.x | Full-text article search, faceted filtering, analytics aggregations |
| Pinecone or Weaviate | Latest stable | Semantic similarity search, narrative clustering, duplicate detection |
| Apache Kafka | 3.6+ | Event backbone — all pipeline stages, audit trail, replayable log |

### Core Kafka Topics

- `article.ingested` — raw normalized articles from ingestion-service
- `article.enriched` — NLP-enriched articles from nlp-service
- `article.verified` — fact-checked, verdict-assigned articles from integrity-service
- `article.ingestion.dlq` — failed articles with error metadata
- `notification.triggers` — alert rule matches for the notification-service
- `audit.events` — all immutable audit records

### Key PostgreSQL Entities

**users** — id, email (encrypted), password_hash (Argon2id), role (ENUM), mfa_secret, gdpr_consent_at, account_status

**articles** — id, source_id, title, body, canonical_url, url_hash (dedup), published_at, language, raw_payload (JSONB)

**article_enrichments** — article_id (1:1), summary, entities (JSONB), topics (JSONB), sentiment_label, sentiment_score, embedding_id

**integrity_verdicts** — article_id (1:1), verdict (ENUM: VERIFIED/UNVERIFIED/DISPUTED/MISINFORMATION), verdict_at, override_by, override_rationale, provider_unavailable

**verdict_claims** — id, article_id, claim_text, claim_verdict, evidence_url, source_organization, fact_check_provider

**sources** — id, name, url, source_type (RSS/SCRAPER/API), reliability_score (0.0–1.0), fetch_interval_minutes, is_active

**alert_rules** — id, user_id, topic_id[], keyword, verdict_filter, channels (JSONB), is_active

**audit_logs** — id, user_id, action_type, entity_type, entity_id, endpoint, method, jwt_role, ip_address, timestamp (immutable, append-only)

**user_sessions** — id, user_id, refresh_token_hash, expires_at, revoked_at

---

## 🔄 Data Pipeline — End-to-End Flow

Build the following 12-step pipeline exactly:

1. **Source Polling** — ingestion-service scheduler polls RSS/scraper targets at configured intervals (1–60 min per source).
2. **Content Extraction** — parse raw HTML/XML into normalized `ArticleRaw` schema (title, body, author, timestamp, canonical URL, source_id).
3. **Deduplication** — compute `SHA-256(canonical_url + publication_timestamp)`. Check Redis (TTL: 24h). Discard if exists; store hash if new.
4. **Schema Validation** — validate against JSON Schema Draft-07. Failures go to `article.ingestion.dlq` with error metadata.
5. **Kafka Publication** — serialize valid articles as Avro and publish to `article.ingested` (partition key: `source_domain`).
6. **NLP Consumption** — nlp-service consumes `article.ingested` and fires concurrent async LLM calls for: (a) abstractive summarization, (b) NER extraction, (c) sentiment scoring (label + score), (d) topic classification.
7. **Embedding Generation** — chunk article text (max 512 tokens), generate embeddings via `text-embedding-3-large` (or equivalent), upsert to Vector DB with `article_id` as key.
8. **Article Enrichment** — merge NLP outputs into `ArticleEnriched`, persist to PostgreSQL `article_enrichments`, publish to `article.enriched`.
9. **Claim Extraction & Fact-Check** — integrity-service consumes `article.enriched`, extracts verifiable claims via LLM prompt, queries IFCN fact-check API(s) per claim (max 10 concurrent requests per replica; excess queued in Redis).
10. **Source Reliability Scoring** — compute `reliability_score = (0.45 × accuracy_rate) + (0.25 × ifcn_certified) + (0.20 × transparency_score) − (0.10 × retraction_rate)`. Recalculate daily. Badge thresholds: GREEN ≥ 0.7, AMBER 0.4–0.69, RED < 0.4.
11. **Verdict Assignment** — synthesize claim verdicts using logic: any MISINFORMATION claim → MISINFORMATION; >50% DISPUTED → DISPUTED; source reliability < 0.4 → UNVERIFIED; otherwise → VERIFIED. Write to `integrity_verdicts`, publish to `article.verified`, update Elasticsearch.
12. **Notification & Dashboard** — notification-service evaluates alert rules; dashboard-service aggregates from PostgreSQL read replica + Elasticsearch and pushes to frontend via WebSocket.

---

## 🔐 Security Requirements

### Authentication & Authorization
- **JWT** signed with **RS256** (RSA-2048). Access token TTL: **15 minutes**. Refresh token TTL: **7 days** (CONSUMER) / **12 hours** (privileged roles).
- **RBAC** enforced at API Gateway (coarse) and individual services (fine-grained). Every HTTP 403 generates an audit log entry.
- **TOTP MFA** (RFC 6238) mandatory for JOURNALIST, EDITOR, ADMIN, AUDITOR roles. 8 single-use backup codes generated at enrollment.
- **OAuth2 Social Login** via Google and LinkedIn.
- **Brute-force protection**: account locked after 5 failed login attempts in 15 minutes. Unlock via email link (TTL: 1 hour).

### RBAC Permission Matrix

| Role | Permissions |
|---|---|
| CONSUMER | read:articles, read:verdicts |
| JOURNALIST | + read:evidence, export:reports, initiate:manual_factcheck |
| EDITOR | + override:verdicts (with 100-char rationale), configure:alerts, assign:tasks |
| ADMIN | + manage:users, manage:sources, configure:system |
| AUDITOR | + read:audit_logs, export:compliance_reports |

### Encryption
- **Data in transit**: TLS 1.3 minimum. TLS 1.0/1.1 disabled at load balancer.
- **Data at rest**: AES-256-GCM for PostgreSQL (TDE or volume-level). AES-256 for S3/object storage.
- **PII fields** (email, ip_address, user_agent): AES-256-GCM application-layer encryption before write.
- **Passwords**: Argon2id (memory: 64 MB, iterations: 3, parallelism: 4).
- **Secrets**: Zero secrets in code or environment variables. All secrets via HashiCorp Vault or AWS Secrets Manager, injected via External Secrets Operator.

### GDPR Compliance
- Explicit consent checkbox at registration; `gdpr_consent_at` recorded.
- `GET /api/v1/me/data-export` — full PII + activity JSON export within 72 hours.
- `DELETE /api/v1/me` — pseudonymize PII, purge sessions, anonymize audit logs (nullify user_id), send Kafka tombstone for personal data.
- Data retention: PII → account lifetime + 30 days. Audit logs → 7 years. Sessions → purged on expiry/logout.

---

## 🌐 REST API Contract (API Gateway — `api-gateway`)

All endpoints versioned under `/api/v1/`. All responses return `Content-Type: application/json`. Errors return structured body: `{ "error": { "code": "...", "message": "...", "request_id": "..." } }`.

| Endpoint | Method | Min Role | Notes |
|---|---|---|---|
| `/api/v1/auth/register` | POST | PUBLIC | Email + password. Rate limit: 5 req/IP/hour. Returns 201. |
| `/api/v1/auth/login` | POST | PUBLIC | Returns access_token + refresh_token. |
| `/api/v1/auth/refresh` | POST | PUBLIC | Rotates refresh token on each use. |
| `/api/v1/auth/mfa/setup` | POST | Authenticated | Returns TOTP QR code + backup codes. |
| `/api/v1/articles` | GET | CONSUMER | Cursor-based pagination (default 20, max 100). Filters: topic_id[], source_id[], verdict, sentiment, date_from, date_to, q, language. |
| `/api/v1/articles/{id}` | GET | CONSUMER | Evidence trail visible for JOURNALIST+ only. |
| `/api/v1/articles/{id}/similar` | GET | CONSUMER | Top 5 from Vector DB (min similarity: 0.75). |
| `/api/v1/articles/{id}/factcheck` | POST | JOURNALIST | Returns 202 with job_id. |
| `/api/v1/sources` | GET | CONSUMER | All active sources with reliability scores. |
| `/api/v1/sources` | POST | ADMIN | Register new source. |
| `/api/v1/topics` | GET | CONSUMER | Full topic taxonomy tree. |
| `/api/v1/analytics/trends` | GET | JOURNALIST | Topic frequency + sentiment trend data. |
| `/api/v1/alerts` | GET/POST/DELETE | Authenticated | CRUD for personal alert rules. |
| `/api/v1/audit/logs` | GET | AUDITOR, ADMIN | Paginated, filterable audit log. |
| `/api/v1/admin/system-health` | GET | ADMIN | Kafka consumer lag, DLQ counts, service statuses, LLM quota. |
| `/api/v1/me/data-export` | GET | Authenticated | GDPR data export. |
| `/api/v1/me` | DELETE | Authenticated | GDPR erasure. |

### WebSocket Events (from `api-gateway`)

| Event | Direction | Trigger |
|---|---|---|
| `article.published` | Server → Client | New verified article matching client's active filters |
| `alert.triggered` | Server → Client | Alert rule match for this user |
| `system.maintenance` | Server → Client | Admin broadcast |

WebSocket debounce: max 1 push per client per 500ms.

---

## 🖥️ Frontend — React 18 / TypeScript

### Screens to Build

**1. News Feed (All authenticated users)**
- Masonry-grid / list-view toggle (user preference persisted).
- Article card: headline (truncated at 120 chars), source name, reliability badge (GREEN/AMBER/RED), relative timestamp (absolute on hover), integrity verdict badge, 2-sentence summary, topic tags (max 3 + "+N more"), sentiment icon.
- Left sidebar: filter panels for Topics, Sources, Date Range, Verdict Status, Sentiment, Language. Live article count updates as filters apply.
- Real-time updates via WebSocket with 500ms debounce.
- P95 initial load time: ≤ 1.5s under 500 concurrent users.

**2. Article Detail (Role-gated content)**
- Two-column layout (70/30 desktop; single-column below 768px).
- Primary: full summary, inline NER annotations with tooltips + entity profile links, topic breadcrumb, sentiment bar.
- Secondary: source card + reliability sparkline, verdict card + expandable claim evidence list (JOURNALIST+ only), related articles panel (Vector DB semantic similarity).

**3. Analytics Dashboard (JOURNALIST / EDITOR / ADMIN)**
- Drag-and-drop widget grid (layout persisted per user in DB).
- Widgets: Topic Frequency Heatmap (D3.js), Source Reliability Matrix, Misinformation Timeline (recharts), Narrative Cluster Graph (force-directed, vis.js), Sentiment Trend Line Chart, Article Volume Bar Chart, Top Named Entities Table.
- Per-widget date range + filter controls.
- Export Dashboard: PDF (Puppeteer server-side) or CSV.

**4. Administration Panel (ADMIN only)**
- Tabs: Users (CRUD, role assignment, MFA status, lock/unlock), Sources (register, configure fetch interval + scraping selectors, activate/deactivate), System Health (Kafka consumer lag, service statuses, DLQ counts, LLM API quota), LLM Configuration (provider, model, temperature, max_tokens), Alert Rule Templates.

**5. Audit Log Viewer (AUDITOR / ADMIN)**
- Paginated, filterable table with export to CSV/JSON.

---

## 📊 Non-Functional Requirements

| Metric | Target |
|---|---|
| API P95 response time (read) | ≤ 200ms |
| API P95 response time (write) | ≤ 500ms |
| Ingestion-to-verdict latency (P95) | ≤ 5 minutes end-to-end |
| Platform uptime SLA | ≥ 99.9% (monthly) |
| Concurrent WebSocket connections | ≥ 10,000 |
| MTBF | > 720 hours |
| MTTR (P1 incidents) | < 30 minutes |
| RTO | < 2 hours |
| RPO | < 15 minutes (PostgreSQL streaming replication, 15-min snapshots) |
| Kafka durability | Zero message loss (`min.insync.replicas=2`, `acks=all`) |

**Graceful Degradation:** If NLP service is unavailable → serve articles without summaries. If integrity service is unavailable → show verdicts as PENDING. No single-service failure causes full platform outage.

---

## 🛠️ CI/CD & Code Standards

### Language Standards

| Language | Standard |
|---|---|
| Python | PEP 8 via Ruff. Type annotations required (mypy strict). Google-style docstrings. Coverage: ≥80% unit, ≥60% integration. |
| TypeScript | ESLint Airbnb config. Prettier. `noImplicitAny: true`. Jest (unit), Playwright (E2E). |
| SQL Migrations | Alembic. Every `up` migration must have a reversible `down`. |
| API Contracts | OpenAPI 3.1 spec in `/docs/api/`. Auto-generated from FastAPI annotations. Contract-tested via Schemathesis. |
| IaC | Terraform for all infra. Helm charts for Kubernetes. `terraform plan` in CI before apply. |

### CI/CD Pipeline (GitHub Actions)

| Stage | Gate |
|---|---|
| Code Commit | Ruff + ESLint pass. mypy + tsc pass. Gitleaks (no secrets). |
| Unit Test | All tests pass. Coverage thresholds met. |
| Integration Test | Docker Compose (real Kafka + PostgreSQL + Redis). All API contract tests pass. |
| Security Scan | Trivy (zero critical CVEs). OWASP ZAP FAIL-level = zero. Semgrep SAST clean. |
| Build & Push | Docker buildx multi-arch (linux/amd64, linux/arm64). Cosign image signing. |
| Staging Deploy | Helm upgrade. Smoke tests + performance regression (< 10% degradation). |
| Production Deploy | Manual ADMIN approval gate. Rolling update (max-surge: 1, max-unavailable: 0). |

---

## 🔌 Extensibility Contracts — Build These Abstractions

Your implementation **must** include these extension points so future development requires zero changes to core logic:

1. **`BaseSourceAdapter`** (ingestion-service) — abstract class for data source types. New sources (e.g., podcast transcripts) are added by implementing the adapter and registering the `source_type` ENUM. No changes to core ingestion logic.

2. **`LLMClient` abstraction layer** (nlp-service, integrity-service) — registered provider implementations for OpenAI, Anthropic, and self-hosted Ollama. Switching providers = config change + new provider class only.

3. **`BaseFactCheckProvider`** (integrity-service) — interface for fact-check provider integration. Multi-provider consensus logic isolated in the verdict synthesis layer.

4. **Widget Registry** (frontend) — new analytical widgets registered as React components conforming to `WidgetProps` interface, appearing automatically in the widget selector.

---

## 🚀 Getting Started — Implementation Order

Follow this sequence to avoid dependency bottlenecks:

1. **Infrastructure first** — Provision Kubernetes cluster. Deploy Kafka (3-broker), PostgreSQL (primary + read replica), Redis (3-node Sentinel), Elasticsearch (3-node). All via Terraform + Helm.
2. **Database schema** — Write and apply all Alembic migrations. Seed topic taxonomy and test sources.
3. **user-service** — Auth foundation everything depends on. Ship JWT issuance, RBAC middleware, TOTP MFA.
4. **api-gateway** — JWT verification middleware, request routing, rate limiting.
5. **ingestion-service** — Full pipeline from polling to `article.ingested` Kafka publication.
6. **nlp-service** — Consume `article.ingested`, run LLM enrichment, publish `article.enriched`.
7. **integrity-service** — Consume `article.enriched`, fact-check, assign verdicts, publish `article.verified`.
8. **notification-service + audit-service** — Consume `article.verified` and `audit.events`.
9. **dashboard-service (BFF)** — Aggregate read APIs + WebSocket event relay.
10. **frontend** — News feed → Article detail → Analytics dashboard → Admin panel → Audit viewer.
11. **CI/CD** — Wire up all pipeline stages. Security scans. Container signing.
12. **Hardening** — Load testing, chaos engineering, GDPR compliance verification, penetration test readiness.

---

## 📎 Constraints & Non-Negotiables

- **Never** store secrets in environment variables, code, or configuration files. Vault/Secrets Manager only.
- **Never** allow direct cross-service database access. Kafka is the contract.
- **Never** use `WidthType.PERCENTAGE` in any document generation. (DXA only.)
- **Always** use parameterized queries. No raw SQL string interpolation anywhere.
- **Always** log every HTTP 403 to audit_logs with full context.
- **Always** run `terraform plan` in CI before any `terraform apply`.
- LLM inference is external (no self-hosted GPU in v1.0). Budget API calls appropriately.
- Minimum test coverage: 80% unit (Python), 70% unit (TypeScript).

---

## ✅ Definition of Done

A feature is **done** when:
- [ ] All acceptance criteria from the corresponding FR-* requirement are met.
- [ ] Unit + integration tests written and passing at coverage threshold.
- [ ] OpenAPI spec updated and Schemathesis tests passing.
- [ ] No critical Trivy CVEs in the container image.
- [ ] Alembic migration (up + down) written and verified.
- [ ] Audit logging implemented for all write operations and access violations.
- [ ] Feature deployed to staging and smoke-tested.
- [ ] ADMIN approval obtained for production promotion.

---

*NewsRadar SRS v1.0 | IEEE 830 / ISO/IEC/IEEE 29148:2018 | Internal — Restricted Distribution*
