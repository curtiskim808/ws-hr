# Technical Design Document

**Version:** 1.0
**Date:** January 21, 2026
**Status:** Approved for MVP

---

## Table of Contents

1. [Overview](#1-overview)
2. [Scope](#2-scope)
3. [System Architecture](#3-system-architecture)
4. [Functional Requirements](#4-functional-requirements)
5. [Technical Specifications](#5-technical-specifications)
6. [API Documentation](#6-api-documentation)
7. [Database Schema Design](#7-database-schema-design)
8. [Performance and Scalability](#8-performance-and-scalability)
9. [Deployment Strategy](#9-deployment-strategy)
10. [Assumptions](#10-assumptions)

---

## 1. Overview

### 1.1 Purpose

The WS-HR MGMT System is a **multi-tenant(brand), API-only** Hiring Management platform built with Ruby on Rails. It provides a complete hiring workflow from job posting creation to candidate hiring, designed to serve multiple brands (companies) from a single deployment.

### 1.2 Business Objectives

- Streamline the hiring process from job posting to candidate onboarding
- Provide multi-tenant(brand) architecture for supporting multiple brands/companies
- Enable role-based access control(RBAC) for different user types (Admin, Hiring Manager, Interviewer)
- Automate hiring pipeline stages and notifications
- Deliver a scalable, maintainable API for frontend and mobile integrations

### 1.3 Key Stakeholders

| Stakeholder | Role | Interest |
|-------------|------|----------|
| HR Administrators | Primary Users | Manage entire hiring workflow |
| Hiring Managers | Power Users | Create job postings, manage applications |
| Interviewers | Limited Users | View candidates, provide feedback |
| Engineering Team | Developers | Build and maintain the system |
| Operations | DevOps | Deploy and monitor the system |

### 1.4 Document Conventions

- **MUST**: Mandatory requirement
- **SHOULD**: Recommended but not mandatory
- **MAY**: Optional feature
- **MVP**: Minimum Viable Product scope

---

## 2. Scope

### 2.1 MVP Scope (Phase 1) - Current Implementation

The MVP focuses on the **essential hiring workflow**:

```
Position Template → Job Posting → Application → Stage Progression → Hire/Reject
```

| Feature Area | Status | Description |
|--------------|--------|-------------|
| Authentication | Implemented | JWT-based authentication with Devise |
| Position Templates | Implemented | CRUD for job templates |
| Job Postings | Implemented | Create from templates, publish/unpublish |
| Applicants | Implemented | Candidate management |
| Applications | Implemented | Full hiring pipeline with stages |
| Notifications | Implemented | AWS SNS integration via background jobs |
| Multi-tenancy | Implemented | Brand-based data isolation |

### 2.2 Future Phases

#### Phase 2 (Planned)
- Availability Slots (Interviewer scheduling)
- Interview Scheduling
- Evaluation Plans & Scoring (Match scores (AI))
- Advanced File System

#### Phase 3 (Future)
- Reporting Dashboard & Analytics
- Data Export & Templates
- Advanced Filtering & Search
- Background Check Integration

### 2.3 Out of Scope

- Frontend web application (API-only backend)
- Email template customization UI
- Real-time chat/messaging
- Video interview integration
- AI-powered resume parsing
- CI/CD

---

## 3. System Architecture

### 3.1 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Client Applications                           │
│                  (Web Frontend, Mobile App, Third-party)                │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ HTTPS/REST API
                                  │ JWT Authentication
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Load Balancer / API Gateway                        │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Rails API Server (Port 3000)                         │
│  ┌──────────────────────────────────────────────────────────────-──┐    │
│  │  API Controllers (Thin Controller Pattern)                      │    │
│  │  ├── AuthController (login/logout)                              │    │
│  │  ├── PositionTemplatesController                                │    │
│  │  ├── JobPostingsController                                      │    │
│  │  ├── ApplicantsController                                       │    │
│  │  └── ApplicationsController                                     │    │
│  └───────────────────────────┬───────────────────────────────────-─┘    │
│                              │                                          │
│  ┌───────────────────────────▼───────────────────────-─────────────┐    │
│  │  Models (Fat Model Pattern)                                     │    │
│  │  ├── BrandScoped concern (multi-tenant isolation)               │    │
│  │  ├── AASM state machines (Application, JobPosting)              │    │
│  │  ├── Authorization methods (role-based access)                  │    │
│  │  └── Workflow methods (hire!, reject!, advance_to_stage!)       │    │
│  └───────────────────────────┬────────────────────────────────-────┘    │
│                              │                                          │
│  ┌───────────────────────────▼─────────────────────────────────-───┐    │
│  │  Serializers (JSON:API format via jsonapi-serializer)           │    │
│  └─────────────────────────────────────────────────────────────-───┘    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   PostgreSQL 15  │   │     Redis 7      │   │   Solid Queue    │
│    (Database)    │   │ (Cache/Sessions) │   │ (Background Jobs)│
│                  │   │                  │   │                  │
│ • brands         │   │ • JWT denylist   │   │ • NotificationJob│
│ • users          │   │ • Session cache  │   │ • Future jobs    │
│ • locations      │   │ • Query cache    │   │                  │
│ • position_tmpl  │   │                  │   │                  │
│ • job_postings   │   │                  │   │                  │
│ • applicants     │   │                  │   │                  │
│ • applications   │   │                  │   │                  │
│ • hiring_stages  │   │                  │   │                  │
└──────────────────┘   └──────────────────┘   └────────┬─────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │     AWS SNS      │
                                              │  (Notifications) │
                                              │                  │
                                              │ • Email alerts   │
                                              │ • SMS alerts     │
                                              │ • Push notifs    │
                                              └──────────────────┘
```

### 3.2 Technology Stack

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Framework | Ruby on Rails | 8.0.4 | API-only backend |
| Language | Ruby | 3.4.1 | Application language |
| Database | PostgreSQL | 15+ | Primary data store |
| Cache | Redis | 7+ | Caching and sessions |
| Background Jobs | Solid Queue | Latest | Async job processing |
| Authentication | Devise + JWT | devise-jwt | Stateless auth |
| API Format | jsonapi-serializer | Latest | JSON:API responses |
| State Machines | AASM | Latest | Workflow management |
| Containerization | Docker | 24+ | Development/Deployment |
| Testing | RSpec | 7.x | Test framework |

### 3.3 Design Patterns

| Pattern | Implementation | Purpose |
|---------|----------------|---------|
| **Fat Model, Thin Controller** | Business logic in models | Maintainability, testability |
| **Multi-tenant (Row-level)** | BrandScoped concern | Data isolation per brand |
| **State Machine** | AASM gem | Application/JobPosting lifecycle |
| **Current Attributes** | Rails Current class | Request-scoped context |
| **Repository Pattern** | ActiveRecord scopes | Query abstraction |
| **Background Jobs** | Solid Queue | Async notification delivery |

#### DHH Style Architecture
> Following DHH's 37signals philosophy, this implementation emphasizes:

- Fat Models: All business logic lives in models (Application#hire!, JobPosting#publish!, etc.)
- Thin Controllers: 1-5 line actions only, strictly REST (no custom actions)
- Current Attributes: Current.user and Current.brand available throughout app
- User-based Authorization: Current.user.can_manage_application?(@application) instead of Pundit policies
- Fixtures: YAML fixtures for test data instead of FactoryBot
- Bang Methods: State changes use fail-fast bang methods (hire!, reject!, publish!)
- Semantic Naming: set_ prefix for private setters, {model}_params for strong parameters
- No Service Objects: Business logic encapsulated in fat models, not separate service classes
- Transaction Safety: after_commit callbacks for ALL side effects (notifications, broadcasts, cache invalidation)

### 3.4 Request Flow

```
1. Client sends request with JWT token
                    │
2. Rails receives request
                    │
3. authenticate_api_user! validates JWT
                    │
4. BrandScoped sets Current.brand from user
                    │
5. Controller delegates to Model (thin controller)
                    │
6. Model executes business logic (fat model)
                    │
7. Serializer formats response (JSON:API)
                    │
8. Response returned to client
```


      
### 3.5 Architecture Decisions (Confirmed)                                                                                                                                                                
                                                                                                                                                                                                       
  | Decision | Choice | Rationale |                                                                                                                                                                    
  |----------|--------|-----------|                                                                                                                                                                    
  | Multi-tenancy | **Brand-based isolation** | Each brand is a tenant with isolated data |                                                                                                            
  | Authentication | **JWT tokens** | Stateless, scalable for API-only backend |                                                                                                                       
  | File Storage | **Local (ActiveStorage)** | Simple for MVP, can migrate to S3 later |                                                                                                               
  | Notifications | **AWS SNS** | Decouple via external notification-service |                           


---

## 4. Functional Requirements

### 4.1 User Stories - MVP

  #### Roles                                                                                                                                                                                            
                                                                                                                                                                                                       
  | Role | Description |                                                                                                                                                                               
  |------|-------------|                                                                                                                                                                               
  | Super Admin | Full system access |                                                                                                                                                                 
  | Admin | Manage hiring processes, templates, all applicants |                                                                                                                                       
  | Hiring Manager | Manage job postings, applicants for assigned locations |                                                                                                                          
  | Interviewer | View assigned interviews, update interview status |                                                                                                                                  
             


#### US1: Position Template Management
| ID | As a | I want to | So that |
|----|------|-----------|---------|
| US1.1 | Admin | Create position templates | I can standardize job descriptions |
| US1.2 | Admin | Edit/Delete templates | I can maintain template library |
| US1.3 | Hiring Manager | View templates | I can create job postings |
| US1.4 | System | Filter templates by status/category | Users find templates quickly |

#### US2: Job Posting Management
| ID | As a | I want to | So that |
|----|------|-----------|---------|
| US2.1 | Hiring Manager | Create job posting from template | I can quickly open positions |
| US2.2 | Hiring Manager | Publish/Unpublish postings | I control job visibility |
| US2.3 | Admin | Set posting to link-only | Private positions are accessible |
| US2.4 | System | Filter postings by status/location | Users find postings quickly |

#### US3: Application Management
| ID | As a | I want to | So that |
|----|------|-----------|---------|
| US3.1 | Applicant | Submit application (public) | I can apply for jobs |
| US3.2 | Hiring Manager | View applications | I can review candidates |
| US3.3 | Hiring Manager | Advance applicant to next stage | Pipeline progresses |
| US3.4 | Hiring Manager | Hire/Reject applicant | Decisions are recorded |
| US3.5 | System | Track stage transitions | Audit trail exists |

#### US4: Applicant Management
| ID | As a | I want to | So that |
|----|------|-----------|---------|
| US4.1 | Admin | View all applicants | I can manage candidate pool |
| US4.2 | Admin | Flag suspicious applicants | I can mark problematic profiles |
| US4.3 | Admin | Create applicant manually | Walk-in candidates are tracked |

### 4.2 Authorization Matrix

| Resource | Super Admin | Admin | Hiring Manager | Interviewer | Public |
|----------|-------------|-------|----------------|-------------|--------|
| **Position Templates** |
| Create | True | True | True | False | False |
| Read | True | True | True | True | False |
| Update | True | True | True | False | False |
| Delete | True | True | True | False | False |
| **Job Postings** |
| Create | True | True | True | False | False |
| Read | True | True | True | False | False |
| Update | True | True | True | False | False |
| Delete | True | True | True | False | False |
| Publish | True | True | True | False | False |
| **Applications** |
| Submit | True | True | True | True | True |
| Read | True | True | True | True | False |
| Update | True | True | True | False | False |
| Hire/Reject | True | True | True | False | False |
| **Applicants** |
| Create | True | True | True | False | False |
| Read | True | True | True | True* | False |
| Update | True | True | True | False | False |
| Flag | True | True | True | False | False |

*Interviewer access is limited to applicants with assigned interviews.*

### 4.3 State Machines

#### Application Status Flow

```
                      ┌─────────────────┐
                      │   in_progress   │ (initial state)
                      └────────┬────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
      hire │          reject   │           archive │
           │                   │                   │
           ▼                   ▼                   ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │    hired     │   │   rejected   │   │   archived   │
    └──────────────┘   └──────────────┘   └──────────────┘
```

#### Job Posting Status Flow

```
         ┌───────────┐
         │   draft   │ (initial state)
         └─────┬─────┘
               │ publish!
               ▼
         ┌───────────┐
    ┌────│ published │────┐
    │    └─────┬─────┘    │
    │          │          │
    │ publish! │ unpublish! make_link_only!
    │          │          │
    │          ▼          │
    │   ┌─────────────┐   │
    └───│ unpublished │   │
        └─────────────┘   │
                          ▼
                  ┌───────────┐
                  │ link_only │
                  └───────────┘
```

---

## 5. Technical Specifications

### 5.1 Background Job Processing: Solid Queue vs Sidekiq

#### Decision: Solid Queue (Selected)

| Criteria | Solid Queue | Sidekiq |
|----------|-------------|---------|
| **Redis Dependency** |  Not required (uses PostgreSQL) |  Required |
| **Rails Native** | Built into Rails 8 | Third-party gem |
| **Simplicity** | Zero external dependencies | Requires Redis setup |
| **Maintenance** | First-party support | Community maintained |
| **Debugging** | Jobs in DB, easy to inspect | Requires Sidekiq Web UI |
| **Performance** | Good for moderate load | Excellent for high load |
| **Concurrency** | Limited by DB connections | Highly concurrent |
| **Cost** | Free | Free (Pro = paid) |

**Pros of Solid Queue:**
1. **Simplified Infrastructure** - No Redis required, fewer moving parts
2. **Database-backed** - Jobs persist in PostgreSQL, surviving restarts
3. **Rails Native** - First-class support, long-term maintenance guaranteed
4. **Debuggability** - Easy to query job status via SQL
5. **Transactional** - Jobs can be part of database transactions

**Cons of Solid Queue:**
1. **Performance Ceiling** - Not ideal for millions of jobs/day
2. **Database Load** - Adds load to PostgreSQL
3. **Limited Ecosystem** - Fewer plugins than Sidekiq
4. **Newer** - Less battle-tested than Sidekiq

**Why Solid Queue for This Project:**
- MVP scale: ~1,000-10,000 jobs/day (well within Solid Queue capacity)
- Simpler deployment without Redis dependency
- Better debugging during development
- Can migrate to Sidekiq if scale demands

### 5.2 Authentication: JWT vs Session

#### Decision: JWT (Selected)

| Criteria | JWT | Session-based |
|----------|-----|---------------|
| **Stateless** |  Token contains all info |  Requires session storage |
| **Scalability** |  Easy horizontal scaling | Requires shared session store |
| **Mobile-friendly** |  Works everywhere |  Cookie issues on mobile |
| **API Design** |  RESTful, stateless |  Stateful |
| **Token Revocation** | Requires denylist |  Easy session invalidation |

**Implementation:**
- Using `devise-jwt` gem
- Tokens stored in `Authorization: Bearer <token>` header
- JWT denylist in `jwt_denylists` table for logout

### 5.3 Multi-tenancy: Row-level vs Schema-level

#### Decision: Row-level with `brand_id` (Selected)

| Criteria | Row-level (brand_id) | Schema-per-tenant |
|----------|---------------------|-------------------|
| **Complexity** | Simple queries | Complex migrations |
| **Performance** | Requires indexes | Isolated data |
| **Maintenance** | Single schema | Multiple schemas |
| **Data Isolation** | Logical (requires care) | Physical |

**Implementation:**
- `BrandScoped` concern adds `default_scope` filtering
- All queries automatically filtered by `Current.brand`
- Composite indexes for performance: `(brand_id, status)`

### 5.4 State Management: AASM vs Enum-only

#### Decision: AASM (Selected)

| Criteria | AASM | Plain Enum |
|----------|------|------------|
| **Transitions** | Validates transitions | Manual validation |
| **Callbacks** | Before/after hooks | Manual implementation |
| **Events** | Named events (publish!) | Direct status change |
| **Guards** | Conditional transitions | Manual conditionals |

**Implementation:**
- `Application` model: `in_progress → hired/rejected/archived`
- `JobPosting` model: `draft → published ↔ link_only → unpublished`

---

## 6. API Documentation

### 6.1 Base URL

```
Development: http://localhost:3000/api/v1
Production:  https://api.example.com/api/v1
```

### 6.2 Authentication

#### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "admin@example.com",
  "password": "password123"
}
```

**Response:**
- JWT token in `Authorization` header: `Bearer eyJhbGciOiJIUzI1NiJ9...`
- User data in response body

#### Logout
```http
DELETE /api/v1/auth/logout
Authorization: Bearer <token>
```

### 6.3 Position Templates

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/position_templates` | List templates | True |
| GET | `/position_templates/:id` | Get single template | True |
| POST | `/position_templates` | Create template | Admin/HM |
| PATCH | `/position_templates/:id` | Update template | Admin/HM |
| DELETE | `/position_templates/:id` | Delete template | Admin/HM |

**Query Parameters:**
- `status` - Filter by status (draft, active)
- `category` - Filter by category
- `page[number]` - Page number (default: 1)
- `page[size]` - Items per page (default: 25, max: 100)

### 6.4 Job Postings

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/job_postings` | List postings | Admin/HM |
| GET | `/job_postings/:id` | Get single posting | Admin/HM |
| POST | `/job_postings` | Create posting | Admin/HM |
| PATCH | `/job_postings/:id` | Update/transition status | Admin/HM |
| DELETE | `/job_postings/:id` | Delete posting | Admin/HM |

**Query Parameters:**
- `status` - Filter by status (draft, published, link_only, unpublished)
- `location_id` - Filter by location
- `page[number]` - Page number (default: 1)
- `page[size]` - Items per page (default: 25, max: 100)

**Status Transitions via PATCH:**
```json
{ "job_posting": { "status": "published" } }
```

### 6.5 Applicants

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/applicants` | List applicants | True |
| GET | `/applicants/:id` | Get single applicant | True (Interviewers limited to assigned interviews) |
| POST | `/applicants` | Create applicant | True Admin/HM |
| PATCH | `/applicants/:id` | Update applicant | True Admin/HM |

**Query Parameters:**
- `source` - Filter by source (linkedin, referral, careers_page)
- `flagged` - Filter flagged applicants (true/false)
- `page[number]` - Page number (default: 1)
- `page[size]` - Items per page (default: 25, max: 100)

Note: Interviewers can only view applicants they have interviews with.

### 6.6 Applications

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/applications` | List applications | True |
| GET | `/applications/:id` | Get single application | True |
| POST | `/applications` | Submit application | False Public |
| PATCH | `/applications/:id` | Update/action | Admin/HM |
| DELETE | `/applications/:id` | Archive application | Admin/HM |

**Query Parameters:**
- `status` - Filter by status (in_progress, hired, rejected, archived)
- `job_posting_id` - Filter by job posting
- `location_id` - Filter by location
- `applicant_id` - Filter by applicant
- `page[number]` - Page number
- `page[size]` - Items per page
- `sort` - Sort field (created_at, applied_at, status, applicant_name)
- `direction` - Sort direction (asc, desc)

**Action Types via PATCH:**
```json
// Advance to next stage
{ "action_type": "advance_stage", "stage_id": 2, "notes": "Passed screen" }

// Hire
{ "action_type": "hire" }

// Reject
{ "action_type": "reject", "rejection_reason": "Position filled" }
```

### 6.7 Response Format

**Success Response (JSON:API):**
```json
{
  "data": {
    "id": "1",
    "type": "application",
    "attributes": {
      "status": "in_progress",
      "applicant_name": "Jane Smith",
      "job_title": "Backend Engineer",
      "created_at": "2026-01-20T10:00:00Z"
    },
    "relationships": {
      "applicant": { "data": { "id": "1", "type": "applicant" } },
      "job_posting": { "data": { "id": "1", "type": "job_posting" } }
    }
  },
  "meta": {
    "pagination": {
      "current_page": 1,
      "per_page": 25,
      "total_pages": 4,
      "total_count": 100
    }
  }
}
```

**Error Response:**
```json
{
  "error": "Validation failed",
  "errors": {
    "email": ["can't be blank"],
    "first_name": ["can't be blank"]
  }
}
```

### 6.8 HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | No Content (success with no body) |
| 400 | Bad Request (malformed request) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 422 | Unprocessable Entity (validation error) |
| 500 | Internal Server Error |

---

## 7. Database Schema Design

### 7.1 Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                 BRANDS                                   │
│                           (Multi-tenant Root)                            │
│  ┌────────────┐                                                          │
│  │   brands   │                                                          │
│  │ • id (PK)  │                                                          │
│  │ • name     │                                                          │
│  │ • subdomain│                                                          │
│  │ • settings │                                                          │
│  └──────┬─────┘                                                          │
│         │ 1:N                                                            │
└─────────┼────────────────────────────────────────────────────────────────┘
          │
    ┌─────┴─────────────────────────┬───────────────────────┐
    │                               │                       │
    ▼                               ▼                       ▼
┌────────────┐               ┌────────────┐          ┌──────────────────┐
│  locations │               │   users    │          │position_templates│
│ • id (PK)  │               │ • id (PK)  │          │ • id (PK)        │
│ • brand_id │◄──────────────│ • brand_id │          │ • brand_id       │
│ • name     │               │ • email    │          │ • name           │
│ • city     │               │ • role     │          │ • job_title      │
│ • timezone │               │ • first_name          │ • category       │
└──────┬─────┘               └─────┬──────┘          │ • status         │
       │                           │                 └────────┬─────────┘
       │                           │                          │
       │                     ┌─────┴──────┐                   │
       │                     │ location_  │                   │
       │                     │ assignments│                   │
       │                     └────────────┘                   │
       │                                                      │
       │   ┌──────────────────────────────────────────────────┘
       │   │
       ▼   ▼
┌─────────────────┐        ┌───────────────────┐
│  job_postings   │───────▶│  hiring_processes │
│ • id (PK)       │        │ • id (PK)         │
│ • brand_id      │        │ • brand_id        │
│ • position_template_id   │ • name            │
│ • location_id   │        │ • is_default      │
│ • hiring_process_id      └─────────┬─────────┘
│ • job_title     │                  │ 1:N
│ • status        │                  ▼
└────────┬────────┘        ┌───────────────────┐
         │                 │  hiring_stages    │
         │                 │ • id (PK)         │
         │                 │ • hiring_process_id
         │                 │ • name            │
         │                 │ • position        │
         │                 │ • stage_type      │
         │                 └─────────┬─────────┘
         │                           │
         ▼                           │
┌─────────────────┐                  │
│   applicants    │                  │
│ • id (PK)       │                  │
│ • brand_id      │                  │
│ • email         │                  │
│ • first_name    │                  │
│ • last_name     │                  │
│ • source        │                  │
│ • flagged       │                  │
└────────┬────────┘                  │
         │                           │
         │ 1:N                       │
         ▼                           │
┌─────────────────┐                  │
│  applications   │◄─────────────────┘
│ • id (PK)       │       current_stage_id
│ • brand_id      │
│ • applicant_id  │
│ • job_posting_id│
│ • hiring_process_id
│ • current_stage_id
│ • status        │
│ • applied_at    │
│ • hired_at      │
│ • rejected_at   │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌───────────────────────────┐
│application_stage_transitions│
│ • id (PK)                  │
│ • application_id           │
│ • from_stage_id            │
│ • to_stage_id              │
│ • transitioned_by_id       │
│ • transitioned_at          │
│ • notes                    │
└────────────────────────────┘
```

### 7.2 Core Tables

#### brands
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| name | varchar | NOT NULL | Brand/company name |
| subdomain | varchar | NOT NULL, UNIQUE | URL subdomain |
| settings | jsonb | DEFAULT {} | Brand-specific settings |
| created_at | timestamp | NOT NULL | Creation timestamp |
| updated_at | timestamp | NOT NULL | Update timestamp |

#### users
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| brand_id | bigint | FK, NOT NULL | Brand reference |
| email | varchar | NOT NULL, UNIQUE | Login email |
| encrypted_password | varchar | NOT NULL | BCrypt password |
| role | integer | NOT NULL, DEFAULT 3 | User role enum |
| first_name | varchar | NOT NULL | First name |
| last_name | varchar | NOT NULL | Last name |
| phone | varchar | | Phone number |

**Indexes:**
- `(brand_id, email)` UNIQUE
- `(brand_id, role)`

#### position_templates
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| brand_id | bigint | FK, NOT NULL | Brand reference |
| name | varchar | NOT NULL | Template name |
| job_title | varchar | NOT NULL | Position title |
| category | varchar | NOT NULL | Job category |
| department | varchar | NOT NULL | Department |
| description | text | | Job description |
| requirements | text | | Job requirements |
| location_type | varchar | | remote/onsite/hybrid |
| employment_type | varchar | | full_time/part_time/contract |
| education_requirement | varchar | | Required education |
| status | integer | NOT NULL, DEFAULT 0 | draft/active |

**Indexes:**
- `(brand_id, status)`
- `(brand_id, category)`
- `(brand_id, created_at)`

#### job_postings
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| brand_id | bigint | FK, NOT NULL | Brand reference |
| position_template_id | bigint | FK, NOT NULL | Template reference |
| location_id | bigint | FK, NOT NULL | Location reference |
| hiring_process_id | bigint | FK, NOT NULL | Process reference |
| job_title | varchar | NOT NULL | Customized title |
| description | text | | Customized description |
| requirements | text | | Customized requirements |
| status | integer | NOT NULL, DEFAULT 0 | Posting status |
| published_at | timestamp | | Publication timestamp |
| unpublished_at | timestamp | | Unpublish timestamp |

**Indexes:**
- `(brand_id, status)`
- `(brand_id, location_id)`
- `(brand_id, published_at)`

#### applications
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| brand_id | bigint | FK, NOT NULL | Brand reference |
| applicant_id | bigint | FK, NOT NULL | Applicant reference |
| job_posting_id | bigint | FK, NOT NULL | Job posting reference |
| hiring_process_id | bigint | FK, NOT NULL | Process reference |
| current_stage_id | bigint | FK | Current stage |
| status | integer | NOT NULL, DEFAULT 0 | Application status |
| applied_at | timestamp | NOT NULL | Application timestamp |
| hired_at | timestamp | | Hire timestamp |
| hired_by_id | bigint | FK | User who hired |
| rejected_at | timestamp | | Rejection timestamp |
| rejected_by_id | bigint | FK | User who rejected |
| rejection_reason | text | | Rejection reason |
| archived_at | timestamp | | Archive timestamp |
| notes | text | | Application notes |

**Indexes:**
- `(brand_id, status)`
- `(brand_id, job_posting_id)`
- `(brand_id, applicant_id)`
- `(applicant_id, job_posting_id)` UNIQUE - prevents duplicate applications

### 7.3 Index Strategy

| Table | Index | Purpose |
|-------|-------|---------|
| applications | `(brand_id, status)` | Filter by status per brand |
| applications | `(brand_id, job_posting_id)` | Filter by posting per brand |
| applications | `(applicant_id, job_posting_id)` UNIQUE | Prevent duplicates |
| job_postings | `(brand_id, status)` | Filter by status per brand |
| job_postings | `(brand_id, published_at)` | Recent postings |
| position_templates | `(brand_id, category)` | Filter by category |
| applicants | `(brand_id, email)` UNIQUE | Unique email per brand |

---

## 8. Performance and Scalability

### 8.1 Performance Requirements

| Metric | Target | Notes |
|--------|--------|-------|
| API Response Time (p95) | < 200ms | For typical CRUD operations |
| API Response Time (p99) | < 500ms | Including complex queries |
| Concurrent Users | 100+ | Per instance |
| Database Connections | 20-50 | Per Rails process |
| Background Job Throughput | 1,000/hour | Notification delivery |

### 8.2 Optimization Strategies

#### Database Optimizations
1. **Composite Indexes** - All queries include `brand_id` for multi-tenant filtering
2. **Eager Loading** - Prevent N+1 queries with `includes()`
3. **Connection Pooling** - 5-20 connections per process
4. **Query Caching** - Redis-based query caching for hot data

#### Application Optimizations
1. **Pagination** - All list endpoints paginated (max 100 items)
2. **Selective Serialization** - Only include necessary fields
3. **Background Jobs** - Offload slow operations (notifications)
4. **HTTP Caching** - ETag/Last-Modified headers

#### Caching Strategy
```ruby
# Query Caching (Redis)
Rails.cache.fetch("brand:#{brand_id}:templates:#{status}", expires_in: 5.minutes) do
  PositionTemplate.where(status: status).to_a
end

# HTTP Caching (Client-side)
fresh_when(@template, public: true, etag: true)
```

### 8.3 Scalability Strategy

#### Horizontal Scaling
```
                    ┌─────────────────┐
                    │  Load Balancer  │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Rails App #1   │ │  Rails App #2   │ │  Rails App #3   │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
     ┌─────────────────┐          ┌─────────────────┐
     │   PostgreSQL    │          │      Redis      │
     │   (Primary)     │          │    (Cluster)    │
     │        │        │          └─────────────────┘
     │        ▼        │
     │   (Replicas)    │
     └─────────────────┘
```

#### Scaling Recommendations by Load

| Users | Rails Instances | DB Config | Redis |
|-------|-----------------|-----------|-------|
| < 100 | 2 (redundancy) | Single instance | Single node |
| 100-1,000 | 4-8 | Primary + 1 replica | Single node |
| 1,000-10,000 | 10-20 | Primary + 2 replicas | Cluster |
| > 10,000 | Auto-scaling | Managed RDS + Read replicas | ElastiCache |

### 8.4 Monitoring and Observability

| Tool | Purpose |
|------|---------|
| Rails Logging | Request/response logging |
| PostgreSQL EXPLAIN | Query performance analysis |
| Redis INFO | Cache hit rates |
| APM (Datadog/New Relic) | Application performance |
| CloudWatch/DataDog | Infrastructure metrics |

---

## 9. Deployment Strategy

### 9.1 Deployment Environments

| Environment | Purpose | Infrastructure |
|-------------|---------|----------------|
| Development | Local development | Docker Compose |
| Staging | Pre-production testing | AWS ECS (single instance) |
| Production | Live system | AWS ECS (multi-instance) |


### 9.2 Deployment Steps

1. **Pre-deployment:**
   - Run test suite (RSpec)
   - Run security scan (Brakeman)
   - Build Docker image
   - Push to ECR

2. **Database Migration:**
   - Run `rails db:migrate` as ECS task
   - Verify migration success

3. **Rolling Deployment:**
   - Deploy new tasks (blue-green or rolling)
   - Health check verification
   - Traffic shift to new tasks
   - Old task termination

4. **Post-deployment:**
   - Smoke tests
   - Performance verification
   - Monitoring check

### 9.3 Docker Configuration

```yaml
# docker-compose.yml (Development)
services:
  web:
    build: ./docker/Dockerfile
    ports: ["3000:3000"]
    depends_on: [db, redis]
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/ws_hr_development
      - REDIS_URL=redis://redis:6379/0

  solid_queue:
    build: ./docker/Dockerfile
    command: bundle exec rake solid_queue:start
    depends_on: [web]

  db:
    image: postgres:15
    volumes: [postgres_data:/var/lib/postgresql/data]

  redis:
    image: redis:7
```

### 9.4 Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| DATABASE_URL | PostgreSQL connection string | True |
| REDIS_URL | Redis connection string | True |
| SECRET_KEY_BASE | Rails secret key (32+ chars) | True |
| DEVISE_JWT_SECRET_KEY | JWT signing key (64+ chars) | True |
| AWS_ACCESS_KEY_ID | AWS credentials | For SNS |
| AWS_SECRET_ACCESS_KEY | AWS credentials | For SNS |
| AWS_REGION | AWS region | For SNS |
| SNS_TOPIC_ARN | SNS topic for notifications | For SNS |

---

## 10. Assumptions

### 10.1 Technical Assumptions

| ID | Assumption | Risk if Invalid |
|----|------------|-----------------|
| A1 | PostgreSQL 15+ available | May need to adjust queries |
| A2 | Redis 7+ available | Caching features may differ |
| A3 | Docker available for development | Alternative setup needed |
| A4 | AWS infrastructure for production | Different cloud provider setup |
| A5 | HTTPS termination at load balancer | Need SSL cert in app |

### 10.2 Business Assumptions

| ID | Assumption | Risk if Invalid |
|----|------------|-----------------|
| B1 | Max 10,000 applications/brand/year | May need sharding |
| B2 | Max 100 concurrent users/brand | May need more instances |
| B3 | Standard hiring workflow sufficient | Custom workflow engine needed |
| B4 | English-only UI initially | i18n implementation needed |
| B5 | Single timezone per location | Multi-timezone support needed |

### 10.3 Operational Assumptions

| ID | Assumption | Risk if Invalid |
|----|------------|-----------------|
| O1 | 99.9% uptime SLA | Need redundancy planning |
| O2 | Data retention: 7 years | Archive strategy needed |
| O3 | RPO: 1 hour, RTO: 4 hours | Backup strategy adjustment |
| O4 | DevOps team available | Self-managed infrastructure |

### 10.4 Security Assumptions

| ID | Assumption | Risk if Invalid |
|----|------------|-----------------|
| S1 | JWT tokens are sufficient auth | Session-based fallback |
| S2 | Row-level multi-tenancy secure | Schema-level isolation |
| S3 | SSL/TLS everywhere | Data exposure risk |
| S4 | PII stored in database acceptable | Encryption at rest needed |

### 10.5 Dependencies

| Dependency | Version | Purpose | Alternative |
|------------|---------|---------|-------------|
| Ruby | 3.4.1 | Language runtime | 3.3.x |
| Rails | 8.0.4 | Framework | 7.2.x |
| PostgreSQL | 15+ | Database | MySQL (with changes) |
| Redis | 7+ | Cache | Memcached (limited) |
| Docker | 24+ | Containerization | Podman |
| AWS | N/A | Cloud infrastructure | GCP, Azure |

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| Brand | A tenant/company in the multi-tenant system |
| Position Template | A reusable job description template |
| Job Posting | A published job opening created from a template |
| Applicant | A candidate who has applied to jobs |
| Application | A specific job application from an applicant |
| Hiring Process | A workflow definition with stages |
| Hiring Stage | A step in the hiring process |
| Stage Transition | A record of moving between stages |

---
