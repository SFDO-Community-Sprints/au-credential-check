# Architecture

## Overview

CredentialsCheck is a Salesforce-native credential intake and verification system. It is built entirely with declarative Salesforce tooling - custom objects, record-triggered flows, a screen flow, and an Experience Cloud site. There is no custom Apex code in the current design.

---

## Package Structure

| Directory | Purpose |
|---|---|
| `force-app/main/default/` | All Salesforce metadata - objects, flows, pages, etc. |
| `config/` | Scratch org definition files |
| `scripts/` | Developer utility scripts (SOQL queries, anonymous Apex) |
| `docs/` | Project documentation |

---

## API Version

Currently targeting **API v65.0**. Update `sourceApiVersion` in `sfdx-project.json` when upgrading.

---

## Component Map

```
┌─────────────────────────────────────────────────────────────┐
│                      Salesforce Org                         │
│                                                             │
│  ┌───────────────────┐    ┌──────────────────────────────┐  │
│  │  Credential Type  │◄───│         Credential           │  │
│  │  (Master Object)  │    │    (Transaction Object)      │  │
│  └───────────────────┘    └──────────────┬───────────────┘  │
│                                          │                  │
│                           ┌──────────────▼──────────────┐   │
│                           │    Record-Triggered Flows   │   │
│                           │    - Token Generation       │   │
│                           │    - Requested Date Stamp   │   │
│                           └─────────────────────────────┘   │
│                                          │                  │
│                           ┌──────────────▼──────────────┐   │
│                           │    Credential Request        │   │
│                           │    (Staging Object)          │   │
│                           └──────────────┬──────────────┘   │
│                                          │                  │
│                           ┌──────────────▼──────────────┐   │
│                           │  Credential_Request_Approval │   │
│                           │  (Record-Triggered Flow)     │   │
│                           │  Copies data to Credential   │   │
│                           │  on Status = Approved        │   │
│                           └─────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Scheduled Flow (Nightly)               │    │
│  │  Checks Expiry_Date__c, updates Status__c           │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           Experience Cloud Site (Public)            │    │
│  │  ┌───────────────────────────────────────────────┐  │    │
│  │  │    Intake Screen Flow (System Mode)           │  │    │
│  │  │    - Receives token from URL                  │  │    │
│  │  │    - Validates record and expiry              │  │    │
│  │  │    - Creates Credential Request staging rec   │  │    │
│  │  │    - Collects volunteer input                 │  │    │
│  │  │    - Uploads file to Credential Request       │  │    │
│  │  │    - Updates Credential Status to Under Review│  │    │
│  │  └───────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Submission Link Creation

1. Admin creates `Credential__c` record.
2. `Token Generation Flow` (record-triggered, After Insert) generates a GUID and writes it to `Unique_Token__c`.
3. `Submission_Link__c` formula field assembles the public URL from the site base URL and the token.
4. Admin changes Status to "Requested".
5. `Requested Date Flow` (record-triggered, Before Update) detects the status change and stamps `Requested_Date__c`.
6. Admin copies `Submission_Link__c` from the Highlights Panel and sends it to the volunteer.

### Volunteer Form Submission

1. Volunteer opens the URL. Experience Cloud loads and passes the `id` query parameter to the Intake Screen Flow.
2. Flow performs a SOQL query: `SELECT ... FROM Credential__c WHERE Unique_Token__c = :id`.
3. Flow evaluates the Decision elements:
   - No record found -> "Invalid Link" screen.
   - `Status__c != "Requested"` -> "Already Submitted" screen.
   - `TODAY() > DateValue(Requested_Date__c) + Link_Expiry_Days__c` -> "Link Expired" screen.
4. On success path: flow creates a `Credential_Request__c` staging record (Status = Pending Review, linked to the Credential). This must happen before the screen renders because the file upload component requires a `recordId` at load time.
5. Flow displays the intake screen showing `Credential_Type__r.Type__c`.
6. Volunteer enters `Issued_By__c`, `Expiry_Date__c` (conditionally), and uploads a file.
7. Flow creates `ContentDocumentLink` attaching the uploaded file to the `Credential_Request__c` record.
8. Flow writes `Issued_By__c` and `Expiry_Date__c` to the `Credential_Request__c` record.
9. Flow updates `Credential__c.Status__c` to "Under Review". `Issued_By__c` and `Expiry_Date__c` on the Credential are NOT written - they remain blank until the request is approved.

### Admin Approval

1. Admin opens the Credential record and navigates to the Credential Requests related list.
2. Admin opens the `Credential_Request__c` record to review the submitted data and attached file.
3. Admin changes `Status__c` to "Approved" (or "Rejected").
4. On Approved: `Credential_Request_Approval` (record-triggered After Save flow) fires.
   - Guards against re-fire: checks `$Record__Prior.Status__c != Approved`.
   - Updates the linked `Credential__c` record, writing `Issued_By__c` and `Expiry_Date__c` from the request.
5. Files stay on the `Credential_Request__c` record permanently as an audit trail.

### Nightly Expiry Check

1. Scheduled Flow runs each night.
2. Queries `Credential__c` records where `Status__c = "Active"` and `Expiry_Date__c <= TODAY()`.
3. Batch-updates `Status__c` to "Expired".

---

## External Dependencies

| Dependency | Purpose |
|---|---|
| Experience Cloud | Hosts the public-facing form page |
| Salesforce Files (ContentDocument) | Stores uploaded credential documents |
| Standard Email (Salesforce Email Actions) | Sends submission confirmation to Contact/Account |

---

## Key Boundaries and Interfaces

- The only public interface is the Experience Cloud site URL with a `?id=` query parameter.
- The Intake Flow is the sole mechanism that reads or writes `Credential__c` on behalf of external users. No other entry point should be available to the Guest User.
- Internal admins interact with Credential records only through standard Lightning record pages.

---

## Development Model

Source-driven development using Salesforce DX. All changes are tracked as source metadata and deployed via `sf project deploy start`. See `docs/environment.md` for setup steps.
