# APIs Document

Base URL: `http://localhost:3000/api/v1`

Swagger UI: `http://localhost:3000/api-docs`

## Table of Contents

- [Authentication](#authentication)
- [Position Templates](#position-templates)
- [Job Postings](#job-postings)
- [Applicants](#applicants)
- [Applications](#applications)
- [Common Response Format](#common-response-format)
- [Error Responses](#error-responses)
- [Authorization Matrix](#authorization-matrix)

## Authentication

### Login

`POST /api/v1/auth/login`

Request:
```json
{
  "email": "admin@acme.example.com",
  "password": "password123"
}
```

Response: JWT token in `Authorization` header
```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

### Logout

`DELETE /api/v1/auth/logout`

Header:
```
Authorization: Bearer <token>
```

### Test Users

| Email | Password | Role |
| --- | --- | --- |
| admin@acme.example.com | password123 | Admin |
| hiring@acme.example.com | password123 | Hiring Manager |
| interviewer@acme.example.com | password123 | Interviewer |

## Position Templates

### List Templates

```
GET /api/v1/position_templates
GET /api/v1/position_templates?status=active
GET /api/v1/position_templates?category=Engineering
GET /api/v1/position_templates?status=active&category=Sales
GET /api/v1/position_templates?page[number]=1&page[size]=10
```

### Get Single Template

`GET /api/v1/position_templates/:id`

### Create Template (Admin/Hiring Manager only)

`POST /api/v1/position_templates`

Request:
```json
{
  "position_template": {
    "name": "Senior Backend Engineer",
    "job_title": "Senior Backend Engineer",
    "category": "Engineering",
    "department": "Product",
    "description": "Build scalable backend services...",
    "requirements": "5+ years experience with Ruby/Python...",
    "location_type": "hybrid",
    "employment_type": "full_time",
    "education_requirement": "bachelors",
    "status": "active"
  }
}
```

### Update Template

`PATCH /api/v1/position_templates/:id`

Request:
```json
{
  "position_template": {
    "status": "draft",
    "requirements": "Updated requirements..."
  }
}
```

### Delete Template

`DELETE /api/v1/position_templates/:id`

## Job Postings

### List Job Postings

```
GET /api/v1/job_postings
GET /api/v1/job_postings?status=published
GET /api/v1/job_postings?status=draft
GET /api/v1/job_postings?location_id=1
GET /api/v1/job_postings?status=published&location_id=1
```

### Get Single Job Posting

`GET /api/v1/job_postings/:id`

### Create Job Posting (from Template)

`POST /api/v1/job_postings`

Request:
```json
{
  "job_posting": {
    "position_template_id": 1,
    "location_id": 1,
    "job_title": "Backend Engineer - NYC",
    "description": "Custom description for this posting..."
  }
}
```

### Update Job Posting

`PATCH /api/v1/job_postings/:id`

Request:
```json
{
  "job_posting": {
    "job_title": "Senior Backend Engineer - NYC",
    "description": "Updated description..."
  }
}
```

### Status Transitions

Publish:
`PATCH /api/v1/job_postings/:id`
```json
{ "job_posting": { "status": "published" } }
```

Make link-only (hidden from careers page):
`PATCH /api/v1/job_postings/:id`
```json
{ "job_posting": { "status": "link_only" } }
```

Unpublish:
`PATCH /api/v1/job_postings/:id`
```json
{ "job_posting": { "status": "unpublished" } }
```

Delete:
`DELETE /api/v1/job_postings/:id`

Status flow: `draft → published ↔ link_only → unpublished`

## Applicants

### List Applicants

```
GET /api/v1/applicants
GET /api/v1/applicants?source=linkedin
GET /api/v1/applicants?source=referral
GET /api/v1/applicants?flagged=true
```

### Get Single Applicant (with applications)

`GET /api/v1/applicants/:id`

### Create Applicant Manually

`POST /api/v1/applicants`

Request:
```json
{
  "applicant": {
    "first_name": "John",
    "last_name": "Doe",
    "email": "john.doe@example.com",
    "phone": "+1-555-1234",
    "source": "referral"
  }
}
```

### Update Applicant (flag suspicious)

`PATCH /api/v1/applicants/:id`

Request:
```json
{
  "applicant": {
    "flagged": true,
    "flag_reason": "Duplicate application detected"
  }
}
```

## Applications

### Submit Application (public - no auth required)

`POST /api/v1/applications`

Request:
```json
{
  "job_posting_id": 1,
  "applicant": {
    "first_name": "Jane",
    "last_name": "Smith",
    "email": "jane.smith@example.com",
    "phone": "+1-555-5678",
    "source": "careers_page"
  },
  "notes": "Very interested in this role"
}
```

### List Applications (filtering & pagination)

```
GET /api/v1/applications
GET /api/v1/applications?status=in_progress
GET /api/v1/applications?status=hired
GET /api/v1/applications?status=rejected
GET /api/v1/applications?job_posting_id=1
GET /api/v1/applications?location_id=1
GET /api/v1/applications?applicant_id=1
GET /api/v1/applications?page[number]=1&page[size]=25
GET /api/v1/applications?sort=created_at&direction=desc
GET /api/v1/applications?sort=applicant_name&direction=asc
GET /api/v1/applications?sort=status
```

### Get Application Detail (with stage history)

```
GET /api/v1/applications/:id
GET /api/v1/applications/:id?include=stage_transitions
```

### Advance to Next Stage

`PATCH /api/v1/applications/:id`

Request:
```json
{
  "action_type": "advance_stage",
  "stage_id": 2,
  "notes": "Passed phone screen, strong communication skills"
}
```

### Hire Applicant

`PATCH /api/v1/applications/:id`

Request:
```json
{ "action_type": "hire" }
```

### Reject Applicant

`PATCH /api/v1/applications/:id`

Request:
```json
{
  "action_type": "reject",
  "rejection_reason": "Position filled by another candidate"
}
```

### Update Application Notes

`PATCH /api/v1/applications/:id`

Request:
```json
{
  "application": {
    "notes": "Follow up scheduled for next week"
  }
}
```

### Archive Application

`DELETE /api/v1/applications/:id`

Application status flow: `in_progress → hired | rejected | archived`

Default hiring stages:
1. Application Review
2. Phone Screen
3. Technical Interview
4. Final Decision

## Common Response Format

All responses follow JSON:API format:
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

## Error Responses

| Status | Meaning |
| --- | --- |
| 401 | Unauthorized - Missing or invalid JWT token |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource doesn't exist or belongs to another brand |
| 422 | Unprocessable Entity - Validation errors |

Example:
```json
{
  "error": "Validation failed",
  "errors": {
    "email": ["can't be blank", "must be a valid email address"],
    "first_name": ["can't be blank"]
  }
}
```

## Authorization Matrix

| Endpoint | Admin | Hiring Manager | Interviewer |
| --- | --- | --- | --- |
| Position Templates (read) | ✅ | ✅ | ✅ |
| Position Templates (write) | ✅ | ✅ | ❌ |
| Job Postings | ✅ | ✅ | ❌ |
| Applicants (read) | ✅ | ✅ | ✅ |
| Applicants (write) | ✅ | ✅ | ❌ |
| Applications (read) | ✅ | ✅ | ✅ |
| Applications (write) | ✅ | ✅ | ❌ |
| Applications (submit) | 🌐 Public | 🌐 Public | 🌐 Public |