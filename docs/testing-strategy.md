# Testing Strategy

## Overview

The solution is built primarily with declarative Salesforce tooling (custom objects, flows, Experience Cloud) alongside Apex classes for functionality that flows cannot express natively (UUID generation, LWC data proxy). The testing approach combines automated Apex unit tests for the code layer and manual end-to-end tests for the declarative and configuration layer.

---

## What Gets Tested and How

### Apex Classes (Automated)

Two Apex classes have `@IsTest` coverage:

**`GenerateUUID`** - invocable action called by the `Credential_Request_Creation` flow.
- Covered by `GenerateUUIDTest.cls`.
- Tests confirm the output is a correctly formatted 36-character UUID string.

**`CredentialSubmissionController`** - without sharing data proxy backing the LWC.
- Covered by `CredentialSubmissionControllerTest.cls` (8 test methods).
- `getCredentialByToken`: valid unexpired token returns OK; unknown token returns INVALID_LINK; actioned request returns ALREADY_SUBMITTED; negative expiry days returns LINK_EXPIRED.
- `submitCredential`: valid token updates request and credential; stale token throws AuraHandledException.
- `uploadFile`: valid request creates ContentVersion; invalid requestId throws AuraHandledException.
- Test data strategy: `@TestSetup` creates hard-coded UUID-format tokens on `Credential_Request__c` records. Expired link scenario uses `Link_Expiry_Days__c = -1` on a separate Credential Type (always expired relative to `CreatedDate`, no need to manipulate dates).

Run tests with:
```
sf apex run test -n CredentialSubmissionControllerTest -o <your-org-alias>
```

### Object and Field Configuration

Tested manually by creating records and verifying field behaviour: auto-number formatting, picklist values, required fields, and field-level security. Covered in the Manual Test Plan, Groups 1 and 2.

### Validation Rules

Tested manually by attempting operations that should be blocked (e.g. activating without sighting) and verifying the error message is correct and actionable. Covered in Manual Test Plan scenario 2.3.

### Record-Triggered Flows

Tested by performing the triggering action (e.g. changing Status to Requested) and verifying the expected side effects (Requested Date stamped, Credential Request created with UUID token). The `Credential_Request_Creation` flow calls the `GenerateUUID` Apex invocable - Apex test coverage for that class contributes to overall org coverage.

### Intake Screen Flow

Tested end-to-end by opening the submission URL in an incognito browser and walking through both the happy path and each error path. Covered in Manual Test Plan, Groups 3 and 4. This is the highest-risk component and must be tested thoroughly before deployment.

### LWC Component

Tested end-to-end by placing the `credentialSubmissionForm` component on an LWR Experience Cloud page and running through all states using a valid token, expired token, unknown token, and already-submitted token. Covered in Manual Test Plan, Group 6. Apex unit tests cover the controller; the component's state transitions and UI must be verified manually.

### Scheduled Flow

Not yet built. When implemented, test by manually triggering the flow in a sandbox with appropriate test data (records with past expiry dates) and verifying status transitions.

---

## Apex Test Standards

- Use `@IsTest(SeeAllData=false)` on all test classes.
- Use `@TestSetup` for shared test data; do not rely on org data in tests.
- Cover both positive (happy path) and negative (exception, invalid input) scenarios.
- Name test methods to describe the scenario and expected outcome: `methodName_condition_expectedResult`.
- Do not test implementation details - test observable behaviour (field values, return values, exceptions thrown).
- Minimum 85% code coverage required for production deployment.

---

## Environments

| Environment | Purpose |
|---|---|
| Scratch org | Active development and initial testing |
| Sandbox | Pre-production validation - run the full Manual Test Plan here |
| Production | Go-live - run smoke tests from the Manual Test Plan after deployment |

---

## Coverage Expectations

- All Apex classes must maintain at least 85% test coverage.
- Every flow path (including all Decision branches) must be manually exercised in a sandbox before deployment.
- Every validation rule must be triggered in both directions (rule fires correctly, rule passes correctly) in a sandbox.
- The full Manual Test Plan must be completed and all scenarios marked Pass before each production deployment.

---

## What Is Not Tested Automatically

- Experience Cloud site configuration and Guest User permissions (manual verification required)
- Email delivery (verify manually in a sandbox with a real email address)
- File upload behaviour with different file types and sizes (manual spot check)
- LWC state transitions and UI rendering (manual walkthrough in browser)
