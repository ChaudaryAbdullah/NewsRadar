# NewsRadar — Agent Development Prompt
### AI-Powered News Intelligence & Information Integrity Platform
**IEEE 830 / ISO/IEC/IEEE 29148:2018 Compliant | SRS v2.0**

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
5. **Serves** an intelligent AI chatbot that answers questions grounded in real fetched news, always surfacing clickable source links alongside every response.

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
| `chatbot-service` | Python 3.11 / FastAPI | Conversational AI engine — RAG over ingested articles, real-time news fetching, source citation with URLs |
| `frontend` | React 18 / TypeScript | Full-featured SPA — news feed, article detail, analytics dashboard, admin panel, audit viewer, chatbot |

---

## 🗄️ Data Layer

### Storage Technologies

| Store | Version | Purpose |
|---|---|---|
| PostgreSQL | 16+ | Primary relational store — articles, users, sources, verdicts, audit logs, alert rules, chatbot conversation history |
| Redis | 7.x | Deduplication cache, session tokens, rate limit counters, real-time trending cache, chatbot session context buffer |
| Elasticsearch | 8.x | Full-text article search, faceted filtering, analytics aggregations |
| Pinecone or Weaviate | Latest stable | Semantic similarity search, narrative clustering, duplicate detection, chatbot RAG retrieval |
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

**chatbot_conversations** — id, user_id, started_at, last_message_at, title (auto-generated from first user message), is_archived

**chatbot_messages** — id, conversation_id, role (ENUM: USER/ASSISTANT), content, created_at, cited_article_ids (JSONB array of article IDs whose URLs were surfaced in the response), fetched_live (BOOLEAN — true if chatbot hit a live news API for this turn)

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
| CONSUMER | read:articles, read:verdicts, use:chatbot |
| JOURNALIST | + read:evidence, export:reports, initiate:manual_factcheck, use:chatbot_advanced |
| EDITOR | + override:verdicts (with 100-char rationale), configure:alerts, assign:tasks |
| ADMIN | + manage:users, manage:sources, configure:system |
| AUDITOR | + read:audit_logs, export:compliance_reports |

**RBAC enforcement rules:**

- Every protected endpoint must verify the JWT role claim at the API Gateway AND re-verify the specific permission at the service layer. Two-layer enforcement is mandatory; gateway-only is not sufficient.
- Role escalation is forbidden client-side. Any request carrying a JWT with a role not matching the user's stored role in the database must be rejected with HTTP 403 and logged to `audit_logs`.
- The chatbot endpoint `/api/v1/chatbot/message` checks `use:chatbot` (CONSUMER+). Advanced RAG features (cross-article evidence synthesis, export to PDF) check `use:chatbot_advanced` (JOURNALIST+). Requests from CONSUMER role to advanced features return HTTP 403.
- Every HTTP 403 — regardless of which service catches it — must publish an `audit.events` record containing: user_id, jwt_role, attempted_permission, endpoint, method, ip_address, timestamp.

### Encryption
- **Data in transit**: TLS 1.3 minimum. TLS 1.0/1.1 disabled at load balancer.
- **Data at rest**: AES-256-GCM for PostgreSQL (TDE or volume-level). AES-256 for S3/object storage.
- **PII fields** (email, ip_address, user_agent): AES-256-GCM application-layer encryption before write.
- **Passwords**: Argon2id (memory: 64 MB, iterations: 3, parallelism: 4).
- **Secrets**: Zero secrets in code or environment variables. All secrets via HashiCorp Vault or AWS Secrets Manager, injected via External Secrets Operator.

### GDPR Compliance
- Explicit consent checkbox at registration; `gdpr_consent_at` recorded.
- `GET /api/v1/me/data-export` — full PII + activity JSON export within 72 hours. Export includes full chatbot conversation history.
- `DELETE /api/v1/me` — pseudonymize PII, purge sessions, anonymize audit logs (nullify user_id), delete chatbot conversation history, send Kafka tombstone for personal data.
- Data retention: PII → account lifetime + 30 days. Audit logs → 7 years. Sessions → purged on expiry/logout. Chatbot conversations → 90 days rolling retention per user.

---

## 🌐 REST API Contract (API Gateway — `api-gateway`)

All endpoints versioned under `/api/v1/`. All responses return `Content-Type: application/json`. Errors return structured body: `{ "error": { "code": "...", "message": "...", "request_id": "..." } }`.

| Endpoint | Method | Min Role | Notes |
|---|---|---|---|
| `/api/v1/auth/register` | POST | PUBLIC | Email + password. Rate limit: 5 req/IP/hour. Returns 201. |
| `/api/v1/auth/login` | POST | PUBLIC | Returns access_token + refresh_token. |
| `/api/v1/auth/refresh` | POST | PUBLIC | Rotates refresh token on each use. |
| `/api/v1/auth/mfa/setup` | POST | Authenticated | Returns TOTP QR code + backup codes. |
| `/api/v1/articles` | GET | CONSUMER | Cursor-based pagination (default 20, max 100). Filters: topic_id[], source_id[], verdict, sentiment, date_from, date_to, q, language. Every article object in the response **must** include `canonical_url` so the frontend can render a clickable source link. |
| `/api/v1/articles/{id}` | GET | CONSUMER | Full article detail. Evidence trail visible for JOURNALIST+ only. Response always includes `canonical_url`, `source.name`, and `source.reliability_score`. |
| `/api/v1/articles/{id}/similar` | GET | CONSUMER | Top 5 from Vector DB (min similarity: 0.75). Each result includes `canonical_url`. |
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
| `/api/v1/chatbot/conversations` | GET | CONSUMER | List user's conversation history (id, title, last_message_at). Paginated. |
| `/api/v1/chatbot/conversations` | POST | CONSUMER | Start a new conversation. Returns conversation_id. |
| `/api/v1/chatbot/conversations/{id}/messages` | GET | CONSUMER | Paginated message history for a conversation. |
| `/api/v1/chatbot/conversations/{id}/messages` | POST | CONSUMER | Send a message. Streams response via SSE. Response includes cited article objects each with `canonical_url`. |
| `/api/v1/chatbot/conversations/{id}` | DELETE | CONSUMER | Delete a single conversation. |

### WebSocket Events (from `api-gateway`)

| Event | Direction | Trigger |
|---|---|---|
| `article.published` | Server → Client | New verified article matching client's active filters |
| `alert.triggered` | Server → Client | Alert rule match for this user |
| `system.maintenance` | Server → Client | Admin broadcast |

WebSocket debounce: max 1 push per client per 500ms.

---

## 🖥️ Frontend — React 18 / TypeScript

### Design System Requirements

Before building any screen, establish a shared design system in `/frontend/src/design-system/`:
- Color tokens for all verdict states (VERIFIED, UNVERIFIED, DISPUTED, MISINFORMATION, PENDING), reliability badges (GREEN, AMBER, RED), sentiment indicators, and role badges.
- Typography scale: display font for headlines, body font for reading content, monospace for metadata and IDs.
- Component library: ArticleCard, VerdictBadge, ReliabilityBadge, SentimentIcon, SourceLink, NERAnnotation, TopicTag, UserRoleBadge, PermissionGate (renders children only if user role satisfies required permission).
- `PermissionGate` is the mandatory wrapper for all role-gated UI sections. It accepts a `requiredPermission` prop and renders `null` (not an error) for insufficient roles, keeping the UI clean without exposing locked sections.

### Screens to Build

---

**Screen 1 — Login / Registration (PUBLIC)**

Build a polished authentication flow with the following states, all on a single route `/auth` with client-side state transitions:

- **Login state**: email + password fields, "Sign in with Google" and "Sign in with LinkedIn" OAuth buttons, "Forgot password" link, link to registration.
- **Registration state**: full name, email, password (strength meter), GDPR consent checkbox (mandatory, blocks submission if unchecked), role selection (CONSUMER pre-selected; upgrading to JOURNALIST/EDITOR/ADMIN requires admin approval — show info tooltip), submit.
- **MFA verification state**: shown after successful credential verification for roles requiring TOTP. 6-digit code entry with auto-advance between digit inputs. "Use backup code" fallback link. Countdown timer showing code validity window.
- **MFA setup state**: shown on first login for newly MFA-enrolled roles. Display TOTP QR code, manual secret key, and list of 8 one-time backup codes with a "I have saved these codes" confirmation checkbox before proceeding.
- **Account locked state**: shown after 5 failed attempts. Display lockout expiry countdown and "Send unlock email" button.
- All form fields must validate inline (not on submit). Errors display beneath the relevant field in a consistent style.
- On successful login, redirect to the last visited route (stored in `sessionStorage`) or `/feed` as default.

---

**Screen 2 — News Feed (CONSUMER+) — Route: `/feed`**

This is the primary content screen and must feel fast, scannable, and real-time.

- **Topbar**: NewsRadar logo, global search input (debounced 300ms, hits `/api/v1/articles?q=`), notification bell with unread count badge, user avatar dropdown (profile link, role badge, sign out).
- **Layout**: left sidebar (filter panel, 240px fixed) + main content area. On mobile (< 768px) the filter panel collapses into a bottom sheet triggered by a filter button.
- **Filter panel** (left sidebar):
  - Verdict filter: checkboxes for VERIFIED, UNVERIFIED, DISPUTED, MISINFORMATION, PENDING. Each checkbox shows live article count in parentheses, updated in real time as other filters change.
  - Topic filter: hierarchical checkbox list from `/api/v1/topics`. Supports expand/collapse of sub-topics.
  - Source filter: multi-select list from `/api/v1/sources` showing source name + reliability badge.
  - Date range: from/to date pickers, preset buttons (Today, Last 7 days, Last 30 days).
  - Sentiment filter: positive / neutral / negative toggles with emoji icons.
  - Language filter: multi-select dropdown.
  - "Reset all filters" button at the bottom.
- **View toggle**: masonry grid / list view, preference persisted to `localStorage`. Default: list view.
- **Article card** (list view) contains:
  - Headline truncated at 120 characters (full text on hover tooltip).
  - Source name with reliability badge (GREEN / AMBER / RED dot).
  - Relative timestamp (e.g., "3 min ago"), switching to absolute datetime on hover.
  - Integrity verdict badge with color and label.
  - 2-sentence AI summary.
  - Topic tags (max 3 displayed + "+N more" chip if more exist).
  - Sentiment icon.
  - **Clickable source link**: rendered as `[Source Name ↗]`, opens `canonical_url` in a new tab. This link must always be present on every article card. Never omit it.
- **Article card** (grid / masonry view): same data, condensed. Headline + source + verdict badge + source link always visible. Summary truncated to 1 sentence.
- **Real-time updates**: WebSocket connection to `article.published` event. New articles matching active filters prepend to the feed with a "N new articles — click to load" banner (not auto-inserted to avoid layout shift). Banner dismissed on click, loading new cards with a smooth transition.
- WebSocket debounce: 500ms. P95 initial load: ≤ 1.5s under 500 concurrent users.

---

**Screen 3 — Article Detail (CONSUMER+) — Route: `/articles/:id`**

Full article view with role-gated sections.

- **Breadcrumb**: Home → Topic → Sub-topic → Article title.
- **Two-column layout** (70/30 desktop, single column below 768px):
  - **Primary column** (70%):
    - Full headline (h1).
    - Publication metadata row: source name (linked to source detail page), author if available, published timestamp, language tag.
    - **Prominent source link**: a clearly visible button or link reading "Read original article ↗" pointing to `canonical_url`, opening in a new tab. This must appear immediately below the metadata row, before any article body content. Style it distinctly so it is never missed.
    - AI-generated summary paragraph with a "Summary" label.
    - Full article body with inline NER annotations: each recognized entity is highlighted with a colored underline. On hover, a tooltip shows entity type (PERSON / ORGANIZATION / LOCATION / EVENT) and a "View profile" link navigating to an entity search results page. NER annotations use distinct color per entity type.
    - Sentiment bar: labeled "Sentiment", shows positive/neutral/negative spectrum with a marker at the article's sentiment score.
    - Topic breadcrumb tags: clickable, each navigates to a filtered feed for that topic.
  - **Secondary column** (30%):
    - **Source card**: source name, URL (linked), reliability score as a numeric value + color badge, a mini sparkline of the source's reliability score over the last 90 days (from analytics endpoint).
    - **Verdict card**: large verdict label (VERIFIED / UNVERIFIED / DISPUTED / MISINFORMATION) with appropriate color. Verdict timestamp. If overridden by an editor, show "Overridden by [editor name] on [date]" with rationale.
    - **Claim evidence list** (`PermissionGate` — JOURNALIST+): expandable accordion. Each claim shows: claim text, per-claim verdict badge, evidence URL (linked, opens in new tab), source organization name, fact-check provider name. Collapsed by default; header shows claim count.
    - **Related articles panel**: top 5 semantically similar articles from Vector DB. Each related article card shows headline (truncated), source + reliability badge, verdict badge, and **source link** (`canonical_url`). Clicking the card navigates to that article's detail page.
- On mobile, secondary column renders below the primary column.

---

**Screen 4 — Analytics Dashboard (JOURNALIST / EDITOR / ADMIN) — Route: `/analytics`**

`PermissionGate` wraps this entire route. CONSUMER attempting to navigate here sees a "Upgrade your access" page with role explanation, not a blank screen or error.

- **Drag-and-drop widget grid**: layout is user-specific, persisted to the database via `PATCH /api/v1/users/me/dashboard-layout`. Implemented with `react-grid-layout`.
- **Widget: Topic Frequency Heatmap** — 7×24 grid (days × hours) showing article volume per topic. Color intensity encodes volume. Built with D3.js. Per-widget topic and date range selectors.
- **Widget: Source Reliability Matrix** — scatter plot of sources by reliability score (x-axis) vs article volume (y-axis). Bubble size encodes verdict distribution. Built with recharts.
- **Widget: Misinformation Timeline** — line chart of MISINFORMATION and DISPUTED article counts over time. Configurable time window. Built with recharts.
- **Widget: Narrative Cluster Graph** — force-directed graph of semantically clustered articles. Nodes colored by topic, edges weighted by semantic similarity. Built with vis.js. Clicking a node navigates to the article detail page.
- **Widget: Sentiment Trend Line Chart** — positive/neutral/negative article ratio over time, as a stacked area chart. Built with recharts.
- **Widget: Article Volume Bar Chart** — articles ingested per source per day. Built with recharts.
- **Widget: Top Named Entities Table** — top 20 entities by mention count, with entity type badge and sparkline of mention frequency over the selected period.
- Every widget has: date range selector, topic filter, minimize button, and remove button. Removed widgets can be re-added from a widget palette accessed via an "Add Widget" button.
- **Export Dashboard**: button triggers server-side PDF generation via Puppeteer (POST to dashboard-service). CSV export downloads raw data behind the current widget configuration.

---

**Screen 5 — Administration Panel (ADMIN only) — Route: `/admin`**

`PermissionGate` wraps this entire route. Non-ADMIN users see a "Forbidden" page with contact admin instructions.

Implemented as a tabbed interface. Active tab persisted in URL query parameter (`?tab=users`).

- **Users tab**:
  - Paginated, searchable table of all users. Columns: avatar, name, email, role badge, MFA status (enabled/disabled), account status (active/locked), registered date, last login.
  - Row actions: Edit role (dropdown, saves immediately with confirmation dialog), Lock/Unlock account (toggle with confirmation), Delete user (soft delete with 30-day recovery window, confirmation modal).
  - Bulk select: checkbox per row, bulk role change, bulk lock, bulk delete.
  - "Invite user" button: sends email invite with a registration link pre-filled with role assignment.

- **Sources tab**:
  - Table of all registered sources with: name, URL (linked), type badge (RSS/SCRAPER/API), reliability score + badge, fetch interval, active status toggle.
  - "Add Source" button: modal form with name, URL, source type selector, fetch interval slider (1–60 min), scraping selector configuration (CSS selectors for title/body/author/date), test connection button.
  - Edit existing source: opens same modal pre-filled.
  - Deactivate: soft-toggle. Deactivated sources are not polled but retained for historical data.

- **System Health tab**:
  - Live-updating service status grid: each microservice shown as a card with name, status indicator (HEALTHY / DEGRADED / DOWN), uptime percentage, last heartbeat timestamp.
  - Kafka consumer lag table: topic name, consumer group, current lag, lag trend sparkline. Rows colored amber if lag > 1,000, red if lag > 10,000.
  - DLQ counts per topic with a "Reprocess DLQ" button (triggers manual reprocessing job, ADMIN only).
  - LLM API quota: provider name, tokens used today, token budget, cost today (USD), cost this month. Progress bar for quota utilization.
  - Auto-refreshes every 30 seconds. Manual refresh button.

- **LLM Configuration tab**:
  - Provider selector: OpenAI / Anthropic / Ollama (self-hosted).
  - Per-task model assignment: summarization model, NER model, sentiment model, topic classification model, claim extraction model, chatbot model. Each is an independent dropdown.
  - Temperature slider (0.0–1.0), max_tokens input, top_p input, per task type.
  - "Test configuration" button: sends a sample article through the NLP pipeline with the staged config and shows the output in a preview panel before saving.
  - Save applies config change via `PATCH /api/v1/admin/llm-config`. Change is audit-logged.

- **Alert Rule Templates tab**:
  - CRUD for platform-wide alert rule templates that users can clone into their personal alert rules.
  - Each template: name, description, trigger condition (verdict type, topic, source reliability threshold, keyword), suggested delivery channels.

---

**Screen 6 — Audit Log Viewer (AUDITOR / ADMIN) — Route: `/audit`**

`PermissionGate` wraps this route. AUDITOR and ADMIN only.

- **Filter bar**: action_type multi-select, entity_type multi-select, jwt_role filter, IP address search input, date range pickers.
- **Paginated table**: columns are timestamp, user (name + role badge), action_type, entity_type, entity_id (clickable if resolvable to a detail page), endpoint, HTTP method, ip_address. 50 rows per page.
- Row click expands an inline detail panel showing full raw audit log JSON.
- **Export**: "Export CSV" and "Export JSON" buttons apply current filter state. Download is streamed, not buffered in memory.
- **No edit, delete, or modify actions exist on this screen.** Audit logs are immutable. The screen is read-only in its entirety.

---

**Screen 7 — AI News Chatbot (CONSUMER+) — Route: `/chat`**

The chatbot is accessible from two entry points: the `/chat` route (full-page experience) and a floating chat button available on every screen (opens a slide-over panel at 420px width, same functionality). Both share the same conversation state via React Context.

### Chatbot Architecture (chatbot-service)

The chatbot must answer user questions with intelligence grounded in real, fetched news. It is not a general-purpose assistant — every substantive factual answer must be backed by articles retrieved from NewsRadar's own corpus or live-fetched from news APIs. Hallucinated facts with no retrievable source are strictly forbidden.

**Retrieval pipeline for each user message:**

1. **Query understanding** — LLM classifies the user's message into: (a) article lookup (user wants specific articles about a topic), (b) factual question (user wants an answer to a question about current events), (c) meta question (user asks about NewsRadar features or verdicts), or (d) conversational (greetings, clarifications).

2. **Hybrid retrieval** — for classes (a) and (b):
   - Vector search: embed the user query and retrieve top-10 semantically similar articles from Pinecone/Weaviate.
   - Keyword search: run the query against Elasticsearch full-text index, retrieve top-10 results.
   - Merge and deduplicate results. Re-rank by recency × relevance score.
   - If the top result is older than 6 hours and the query appears to be about breaking news, trigger a **live news fetch** from the configured external news API (NewsAPI.org, GDELT, or similar). Fetched results are injected into the ingestion pipeline asynchronously AND immediately used for this response turn. `fetched_live = true` is recorded on the message.

3. **Context assembly** — top 5 retrieved/fetched articles are assembled into a context block: for each article, include title, source name, canonical_url, published_at, AI summary, and verdict. This context is injected into the LLM system prompt.

4. **Grounded response generation** — LLM generates the answer using only the provided context. The system prompt explicitly instructs: "Answer only from the provided article context. If the answer is not present in the context, say so clearly and do not speculate."

5. **Source citation** — after generating the answer text, the chatbot appends a structured "Sources" section containing the articles actually referenced in the answer. Each cited source must include:
   - Article title
   - Source name
   - Published timestamp
   - **Canonical URL rendered as a clickable hyperlink** — this is mandatory and non-negotiable. Every response that references a news article must provide the direct link to that article so the user can read the full original piece.
   - Verdict badge

6. **Persist** — save user message and assistant response to `chatbot_messages`. Record `cited_article_ids` and `fetched_live` flag.

### Chatbot Frontend (Screen 7 continued)

**Full-page layout** (`/chat`):
- Left sidebar (280px): conversation history list. Each conversation shows auto-generated title (first user message, truncated to 40 chars) and last message timestamp. "New conversation" button at top. Search conversations input. Delete conversation (trash icon, confirmation tooltip).
- Main area: chat thread with user messages right-aligned (user bubble) and assistant messages left-aligned (assistant bubble). Timestamps on hover.
- Input area at bottom: textarea (auto-expanding, max 4 lines), send button, "Attach article" button (allows pasting an article URL to add as context), character counter.

**Assistant message rendering:**
- Prose answer text rendered as formatted markdown (bold, bullet lists, inline code supported).
- After the prose, a visually distinct "Sources" section with a divider. Each source rendered as a card containing: article title (bold), source name + reliability badge, published timestamp, verdict badge, and a prominent **"Read article ↗"** link pointing to `canonical_url` opening in a new tab.
- If `fetched_live = true` on this message, show a small "🔴 Live" badge on the Sources header indicating the data was fetched in real time.
- Verdict badge on source cards is color-coded identically to the main news feed for visual consistency.

**Floating chat button** (available on all screens):
- Fixed bottom-right corner, 52px circular button with chat icon.
- Opens a slide-over panel (420px wide on desktop, full-width on mobile) layered above current content.
- Panel has the same chat thread view as the full-page experience. "Open full chat" link navigates to `/chat` without losing current conversation.
- Panel can be dismissed by clicking the backdrop or pressing Escape.

**Suggested prompts** (shown in empty conversation state):
- "What's the latest on AI regulation?"
- "Summarize today's top verified stories"
- "Which sources have the highest reliability score right now?"
- "Show me disputed articles about climate change"
- Prompts are role-aware: JOURNALIST+ sees additional prompts like "Find articles I can cross-reference for my investigation" and "Compare coverage of [topic] across sources."

**Chatbot RBAC enforcement:**
- CONSUMER: full chatbot access with standard retrieval (up to 5 cited sources per response).
- JOURNALIST+: advanced retrieval (up to 10 cited sources), cross-article evidence synthesis mode, export conversation to PDF.
- Any chatbot request from an unauthenticated user is rejected at the API Gateway with HTTP 401 before reaching chatbot-service.

---

## 📊 Non-Functional Requirements

| Metric | Target |
|---|---|
| API P95 response time (read) | ≤ 200ms |
| API P95 response time (write) | ≤ 500ms |
| Ingestion-to-verdict latency (P95) | ≤ 5 minutes end-to-end |
| Chatbot first-token latency (P95) | ≤ 800ms (SSE streaming; first token must arrive within 800ms of request) |
| Chatbot full response latency (P95) | ≤ 6 seconds |
| Platform uptime SLA | ≥ 99.9% (monthly) |
| Concurrent WebSocket connections | ≥ 10,000 |
| MTBF | > 720 hours |
| MTTR (P1 incidents) | < 30 minutes |
| RTO | < 2 hours |
| RPO | < 15 minutes (PostgreSQL streaming replication, 15-min snapshots) |
| Kafka durability | Zero message loss (`min.insync.replicas=2`, `acks=all`) |

**Graceful Degradation:**
- If NLP service is unavailable → serve articles without summaries. Summaries show "Processing…" placeholder.
- If integrity service is unavailable → show verdicts as PENDING with a tooltip explaining the delay.
- If chatbot-service is unavailable → floating chat button shows "Chat temporarily unavailable" tooltip. `/chat` route shows a maintenance message.
- If live news fetch API is rate-limited → chatbot falls back to corpus-only retrieval and does not surface a `fetched_live` badge. No error shown to user.
- No single-service failure causes full platform outage.

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

2. **`LLMClient` abstraction layer** (nlp-service, integrity-service, chatbot-service) — registered provider implementations for OpenAI, Anthropic, and self-hosted Ollama. Switching providers = config change + new provider class only.

3. **`BaseFactCheckProvider`** (integrity-service) — interface for fact-check provider integration. Multi-provider consensus logic isolated in the verdict synthesis layer.

4. **`BaseNewsSearchAdapter`** (chatbot-service) — abstract class for live news fetch providers (NewsAPI.org, GDELT, Bing News, etc.). New providers added by implementing the adapter and registering the `news_provider` config key. The chatbot's retrieval pipeline calls the adapter interface — never the provider directly.

5. **Widget Registry** (frontend) — new analytical widgets registered as React components conforming to `WidgetProps` interface, appearing automatically in the widget selector on the analytics dashboard.

---

## 🚀 Getting Started — Implementation Order

Follow this sequence to avoid dependency bottlenecks:

1. **Infrastructure first** — Provision Kubernetes cluster. Deploy Kafka (3-broker), PostgreSQL (primary + read replica), Redis (3-node Sentinel), Elasticsearch (3-node). All via Terraform + Helm.
2. **Database schema** — Write and apply all Alembic migrations including `chatbot_conversations` and `chatbot_messages` tables. Seed topic taxonomy and test sources.
3. **user-service** — Auth foundation everything depends on. Ship JWT issuance, RBAC middleware, TOTP MFA.
4. **api-gateway** — JWT verification middleware, request routing, rate limiting.
5. **ingestion-service** — Full pipeline from polling to `article.ingested` Kafka publication.
6. **nlp-service** — Consume `article.ingested`, run LLM enrichment, publish `article.enriched`.
7. **integrity-service** — Consume `article.enriched`, fact-check, assign verdicts, publish `article.verified`.
8. **notification-service + audit-service** — Consume `article.verified` and `audit.events`.
9. **dashboard-service (BFF)** — Aggregate read APIs + WebSocket event relay.
10. **chatbot-service** — RAG pipeline, live news fetch adapter, SSE streaming endpoint, conversation persistence.
11. **frontend** — Build in screen order: Login/Registration → News Feed (with source links) → Article Detail (with source links) → Analytics Dashboard → Admin Panel → Audit Log Viewer → Chatbot (full-page + floating panel).
12. **CI/CD** — Wire up all pipeline stages. Security scans. Container signing.
13. **Hardening** — Load testing, chaos engineering, GDPR compliance verification, penetration test readiness.

---

## 📎 Constraints & Non-Negotiables

- **Never** store secrets in environment variables, code, or configuration files. Vault/Secrets Manager only.
- **Never** allow direct cross-service database access. Kafka is the contract.
- **Never** use `WidthType.PERCENTAGE` in any document generation. (DXA only.)
- **Always** use parameterized queries. No raw SQL string interpolation anywhere.
- **Always** log every HTTP 403 to audit_logs with full context.
- **Always** run `terraform plan` in CI before any `terraform apply`.
- **Always** include `canonical_url` in every article API response object. It must never be stripped, omitted, or set to null for active articles. The frontend source link depends on it.
- **Always** include at least one cited source with a `canonical_url` in every chatbot response that makes a factual claim about a news event. A response with factual claims and no source links is a defect.
- **Never** allow the chatbot to answer factual news questions from training knowledge alone. All factual responses must be grounded in retrieved or live-fetched articles with verifiable URLs.
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
- [ ] RBAC enforcement verified at both gateway layer and service layer (two-layer test required).
- [ ] For any screen displaying articles: source link (`canonical_url`) rendering verified in Playwright E2E test.
- [ ] For chatbot responses: citation rendering with working `canonical_url` links verified in Playwright E2E test.
- [ ] Feature deployed to staging and smoke-tested.
- [ ] ADMIN approval obtained for production promotion.

---

*NewsRadar SRS v2.0 | IEEE 830 / ISO/IEC/IEEE 29148:2018 | Internal — Restricted Distribution*