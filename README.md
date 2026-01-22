# WS-HIRING-MGMT-APP

A Rails 8 application for managing hiring processes, job postings, applications, and candidate workflows.

## Table of Contents
- [Project Overview](#project-overview)
- [Technical Design Document](#technical-design-document)
- [API Document](#api-document)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Virtual Environment Options](#virtual-environment-options)
- [Project Structure](#project-structure)
- [API Overview](#api-overview)
- [Database Design](#database-design)
- [Testing](#testing)
- [Database](#database)
- [Environment Variables](#environment-variables)
- [Future Development](#future-development)
- [AI Tooling Used](#ai-tooling-used)

## Project Overview

> Ruby on Rails Hiring Mangement System MVP that enables the core hiring workflow

> The system supports multi-tenant(brand) data isolation, RBAC, and publishes notification events to an external notification service

```
Position Templates -> Job Positions -> Applicants -> Interview Scheduling -> Hire/Reject
```


## Technical Design Document

  > Read [Technical Design Document](./docs/technical_design_document.md)

## API Document

> Read [API Document](./docs/apis_document.md)

> Once you running the app check swagger UI api-docs "http://localhost:3000/api-docs/index.html"

## Quick Start

### Docker Setup (Recommended!!)

```bash
# 1. Clone the repository
git clone <repository-url>
cd ws-hr-mgmt

# 2. Create .env file (see SETUP.md for details)
cp .env.example .env

# 3. Start Docker services (virtual environment)
docker-compose up --build

# Startup sequence:
# - Database and Redis start first
# - Web service waits for DB/Redis, then runs migrations automatically
# - Solid Queue waits for web service to complete migrations before starting
# - Database is automatically seeded on first run

# 4. Access the API (wait a few seconds for services to start)
curl http://localhost:3000/api-docs


# 5. Trouble shooting when A server is already running (pid: 1 ...)

rm ./tmp/pids/server.pid
```

### Local Setup (mise)

```bash
git clone <repository-url>
cd ws-hr-mgmt

cp .env.example .env
mise install

bundle install

## EDIT config/database.yml with your local database credentials if necessary

bin/rails db:create db:migrate db:seed

bin/rails server

curl http://localhost:3000/api-docs
```


## Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Applications                     │
│              (Web Frontend, Mobile App, Third-party)            │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS/REST API
                             │ JWT Authentication
                             ▼
┌───────────────────────────────────────────────────────────────-─┐
│                    Rails API Server (Port 3000)                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  API Controllers (Thin)                                  │   │
│  │  - AuthController (login/logout)                         │   │
│  │  - PositionTemplatesController                           │   │
│  │  - JobPostingsController                                 │   │
│  │  - ApplicantsController                                  │   │
│  │  - ApplicationsController                                │   │
│  └───────────────────┬──────────────────────────────────────┘   │
│                      │                                          │
│  ┌───────────────────▼──────────────────────────────────────┐   │
│  │  Models (Fat) -                                          │   │
│  │  - BrandScoped concern (multi-tenant)                    │   │
│  │  - AASM state machines (Application, JobPosting)         │   │
│  │  - Authorization methods (can_manage_application?)       │   │
│  │  - Workflow methods (hire!, reject!, advance_to_stage!)  │   │
│  └───────────────────┬──────────────────────────────────────┘   │
│                      │                                          │
│  ┌───────────────────▼──────────────────────────────────────┐   │
│  │  Serializers (JSON:API format)                           │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ PostgreSQL   │   │    Redis     │   │  Solid Queue │
│  (Database)  │   │   (Cache)    │   │ (Background) │
│              │   │              │   │              │
│ - brands     │   │ - Cache      │   │ - Jobs       │
│ - users      │   │ - Sessions   │   │ - Workers    │
│ - locations  │   │              │   │              │
│ - templates  │   │              │   │              │
│ - postings   │   │              │   │              │
│ - applicants │   │              │   │              │
│ - applications   │              │   │              │
└──────────────┘   └──────────────┘   └──────┬───────┘
                                              │
                                              ▼
                                    ┌─────────────────┐
                                    │   AWS SNS       │
                                    │  (Notifications)│
                                    └─────────────────┘
```

### Technology Stack

- **Framework**: Rails 8.0.4 (API-only)
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **Background Jobs**: Solid Queue (Rails built-in)
- **Authentication**: Devise + JWT (devise-jwt)
- **API Format**: JSON:API
- **State Management**: AASM (state machines)
- **Testing**: RSpec with Fixtures
- **Architecture Style**: DHH/37signals (Fat models, thin controllers)

### Design Patterns

- **Multi-tenant**: Brand-based data isolation via `BrandScoped` concern
- **Role-based Access Control**: User roles (super_admin, admin, hiring_manager, interviewer)
- **State Machines**: AASM for Application and JobPosting lifecycle
- **Fat Models**: Business logic in models (hire!, reject!, publish! methods)
- **Thin Controllers**: 1-5 line actions, only REST verbs
- **Current Attributes**: Request context (Current.user, Current.brand)
- **Background Jobs**: Async notification publishing via Solid Queue

## Virtual Environment Options

This project supports **three setup methods**:

1. **Docker** (Recommended) - Isolated containers, easiest setup
2. **mise** - Local installation using mise (formerly rtx) version manager

### Docker (Recommended)

- Isolated development environment
- Consistent setup across all team members
- No need to install Ruby, PostgreSQL, or Redis locally
- Easy database and service management

### Local Setup (asdf/mise)

- Native performance
- Direct access to tools
- Better IDE integration
- Faster startup times


## Project Structure

```
ws-hr-mgmt/
├── app/
│   ├── controllers/api/v1/    # API endpoints (thin controllers)
│   ├── models/                 # Business logic (fat models)
│   ├── serializers/           # JSON:API serializers
│   ├── jobs/                  # Background jobs (Solid Queue)
├── config/                     # Configuration
│   ├── routes.rb              # API routes
│   ├── database.yml           # Database config
│   └── initializers/         # Devise, AWS, etc.
├── db/                         # Database
│   ├── migrate/               # Migration files
│   ├── seeds.rb               # Seed data
│   └── schema.rb              # Current schema
├── spec/                       # RSpec tests
│   ├── fixtures/              # Test data (DHH style)
│   ├── models/                # Model specs
│   └── requests/               # Request specs
├── docker-compose.yml          # Docker services
├── docker/                     # Docker files
│   └── Dockerfile             # Rails container
```

## API Overview

### Base URL

- **Development**: `http://localhost:3000/api/v1`

### Authentication

All endpoints (except public application submission) require JWT authentication:

```bash
# Login to get token
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@nike.com", "password": "password123"}'

# Use token in subsequent requests
curl -X GET http://localhost:3000/api/v1/position_templates \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Endpoints

#### Authentication
- `POST /api/v1/auth/login` - Login and receive JWT token
- `DELETE /api/v1/auth/logout` - Logout and revoke token

#### Position Templates
- `GET /api/v1/position_templates` - List templates (filterable by status, category)
- `POST /api/v1/position_templates` - Create template
- `GET /api/v1/position_templates/:id` - Get template
- `PATCH /api/v1/position_templates/:id` - Update template
- `DELETE /api/v1/position_templates/:id` - Delete template

#### Job Postings
- `GET /api/v1/job_postings` - List postings (filterable by status, location)
- `POST /api/v1/job_postings` - Create posting from template
- `GET /api/v1/job_postings/:id` - Get posting
- `PATCH /api/v1/job_postings/:id` - Update posting or change status (publish/unpublish)
- `DELETE /api/v1/job_postings/:id` - Delete posting

#### Applicants
- `GET /api/v1/applicants` - List applicants (filterable by source, flagged)
- `POST /api/v1/applicants` - Create applicant manually
- `GET /api/v1/applicants/:id` - Get applicant
- `PATCH /api/v1/applicants/:id` - Update applicant (flag, contact info)

#### Applications
- `GET /api/v1/applications` - List applications (filterable by status, job_posting_id)
- `POST /api/v1/applications` - Submit application (PUBLIC - no auth required)
- `GET /api/v1/applications/:id` - Get application with stage history
- `PATCH /api/v1/applications/:id` - Update application or perform action (hire, reject, advance_stage)
- `DELETE /api/v1/applications/:id` - Archive application

### Response Format

All responses follow JSON:API format:

```json
{
  "data": {
    "id": "1",
    "type": "position_template",
    "attributes": {
      "name": "Software Engineer",
      "job_title": "Senior Software Engineer",
      "status": "active"
    }
  }
}
```

### Error Format

```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Name can't be blank"
    }
  ]
}
```

## Database Design

### Entity Relationship Diagram

> Please take a look at this beautiful diagrams

> [Diagrams](https://drawsql.app/teams/curtis/diagrams/ws-hr)


### Service Startup Order

When running `docker-compose up`, services start in this order:

1. **Database (db)** and **Redis** start first and wait until healthy
2. **Web service** starts after DB/Redis are healthy:
   - Automatically runs `rails db:prepare` (creates DB if needed, runs migrations)
   - Seeds database if empty (first run only)
3. **Solid Queue** starts after web service is started:
   - Waits for database migrations to complete
   - Checks that Solid Queue tables exist before starting
   - This ensures Solid Queue doesn't start before its required tables are created

## Testing

```bash
# Run all tests
docker-compose exec web bundle exec rspec

# Run specific test
docker-compose exec web bundle exec rspec spec/models/user_spec.rb

# With documentation format
docker-compose exec web bundle exec rspec --format documentation

# Run with coverage
docker-compose exec web bundle exec rspec --format documentation --format html --out coverage.html
```

## Database

- **Development**: `ws_hr_app_development`
- **Test**: `ws_hr_app_test`

### Seed Data

After running `rails db:seed`, you'll have:
- 2 brands (Nike, Adidas)
- 4 locations (2 per brand: Vancouver, Toronto)
- 8 users (4 per brand: super_admin, admin, hiring_manager, interviewer)
- 2 hiring processes (1 per brand with 4 stages each)
- 6 position templates (3 per brand)
- 4 job postings (2 per brand, published)

**Default Credentials:**
- Super Admin: `admin@nike.com` / `password123`
- Admin: `manager@nike.com` / `password123`
- Hiring Manager: `hiring@nike.com` / `password123`
- Interviewer: `interviewer@nike.com` / `password123`

## Environment Variables

Required environment variables (see `.env.example`):

- `DB_USERNAME` - PostgreSQL username
- `DB_PASSWORD` - PostgreSQL password
- `SECRET_KEY_BASE` - Rails secret key (32+ characters)
- `DEVISE_JWT_SECRET_KEY` - JWT signing key (64+ characters)
- `AWS_*` - AWS credentials for SNS (optional for local dev)

## Future Development

**Phase 2 - Availability Slots + Interview Scheduling** (Planned):
- Interviewers can set their availability slots
- Endpoints: `GET/POST/PATCH/DELETE /api/v1/availability_slots`
- Schedule interviews with candidates
- Endpoints: `GET/POST/PATCH/DELETE /api/v1/interviews`

**Phase 3 - Reporting** (Planned):
- Reporting Dashboard & Analytics
- Data Export & Templates
- Advanced Filtering & Search
- Background Check Integration


## AI Tooling Used

This project used AI tools to speed up design, implementation, and review. Each tool contributed in a specific way:

- **Context7 MCP**: Pulled up-to-date library documentation and code examples to reduce API guesswork.
- **Claude Skills**: Applied shared Ruby/Rails style guidance and refactoring patterns to keep code consistent.
- **Speckit**: Generated specs, plans, and task lists to keep work structured and traceable.
- **GPT LLM**: Drafted code and explanations, then iterated based on tests and code review feedback.
- **Cursor Agent**: AI-assisted editing, search, coding, and navigation.
- **Claude Code**: Assisted with deeper code reasoning, bug triage, and multi-file changes.
