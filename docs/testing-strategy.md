# Testing Strategy

## Overview

This project is built entirely with declarative Salesforce tooling - custom objects, flows, and Experience Cloud. There is no custom Apex code in the current design. As a result, the testing approach is primarily manual and configuration-based rather than unit-test-driven.

---

## What Gets Tested and How

### Object and Field Configuration

Tested manually by creating records and verifying field behaviour: auto-number formatting, picklist values, required fields, and field-level security. Covered in the Manual Test Plan, Groups 1 and 2.

### Validation Rules

Tested manually by attempting operations that should be blocked (e.g. activating without sighting) and verifying the error message is correct and actionable. Covered in Manual Test Plan scenario 2.3.

### Record-Triggered Flows

Tested by performing the triggering action (e.g. changing Status to "Requested") and verifying the expected side effects (Requested Date stamped, GUID populated). No Apex tests are required for flow execution unless the flow calls Apex invocable actions.

### Intake Screen Flow

Tested end-to-end by opening the submission URL in an incognito browser and walking through both the happy path and each error path. Covered in Manual Test Plan, Groups 3 and 4. This is the highest-risk component and must be tested thoroughly before deployment.

### Scheduled Flow

Tested by manually triggering the flow in a sandbox or scratch org with appropriate test data (records with past expiry dates) and verifying status transitions.

---

## If Apex Is Introduced

If future development adds Apex invocable actions or triggers:
- Write `@IsTest` test classes covering every public method.
- Minimum 85% code coverage is required for deployment to production.
- Test classes must cover both positive (happy path) and negative (exception, invalid input) scenarios.
- Use `@testSetup` for shared test data; do not rely on org data in tests.
- Test bulk behaviour - flows and triggers must handle 200 records without hitting governor limits.

---

## Environments

| Environment | Purpose |
|---|---|
| Scratch org | Active development and initial testing |
| Sandbox | Pre-production validation - run the full Manual Test Plan here |
| Production | Go-live - run smoke tests from the Manual Test Plan after deployment |

---

## Coverage Expectations

Since the solution is declarative:
- Every flow path (including all Decision branches) must be manually exercised in a sandbox before deployment.
- Every validation rule must be triggered in both directions (rule fires correctly, rule passes correctly) in a sandbox.
- The full Manual Test Plan must be completed and all scenarios marked Pass before each production deployment.

---

## What Is Not Tested Automatically

- Experience Cloud site configuration and Guest User permissions (manual verification required)
- Email delivery (verify manually in a sandbox with a real email address)
- File upload behaviour with different file types and sizes (manual spot check)
