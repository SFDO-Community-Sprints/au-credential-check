# Architecture

## Overview

CredentialsCheck is a Salesforce-native credential intake and verification system. It is built on custom objects, record-triggered flows, and an Experience Cloud site. The submission layer now has two parallel implementations: the original Intake Screen Flow and a Lightning Web Component (LWC) alternative for LWR-based Experience Cloud sites.

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
│                           │    - Request Creation       │   │
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
│  │                                                     │    │
│  │  ┌───────────────────────────────────────────────┐  │    │
│  │  │    credentialSubmissionForm LWC (LWR)         │  │    │
│  │  │    - Reads ?id= token via CurrentPageReference│  │    │
│  │  │    - Validates token via Apex (imperative)    │  │    │
│  │  │    - Collects volunteer input                 │  │    │
│  │  │    - Uploads files as base64 via Apex         │  │    │
│  │  │    - Same Credential_Request__c outcome       │  │    │
│  │  └───────────────────────────────────────────────┘  │    │
│  │                    Both backed by                   │    │
│  │  ┌───────────────────────────────────────────────┐  │    │
│  │  │  CredentialSubmissionController (Apex)        │  │    │
│  │  │  without sharing - guest user data proxy      │  │    │
│  │  │  getCredentialByToken / submitCredential /    │  │    │
│  │  │  uploadFile                                   │  │    │
│  │  └───────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Submission Link Creation

1. Admin creates `Credential__c` record (Status = Draft).
2. Admin changes Status to "Requested".
3. `Credential_Requested_Date_Stamp` flow (Before Update) stamps `Requested_Date__c` on the Credential.
4. `Credential_Request_Creation` flow (After Update) creates a `Credential_Request__c` with a new UUID token and Status = Awaiting Submission.
5. `Submission_Link__c` formula field on the request assembles the public URL from the token.
6. Admin copies `Submission_Link__c` from the Credential Request Highlights Panel and sends it to the volunteer.

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

### LWC Submission Path

An alternative to the Intake Screen Flow. Both paths produce the same
`Credential_Request__c` outcome; neither replaces the other.

1. Volunteer opens the URL. LWR Experience Cloud loads the
   `credentialSubmissionForm` component.
2. `@wire(CurrentPageReference)` delivers the page reference; the component
   extracts the `id` query parameter as the token.
3. Component calls `CredentialSubmissionController.getCredentialByToken(token)`
   imperatively. Apex queries `Credential_Request__c WHERE Unique_Token__c = :token`
   and evaluates three gates (no request found, request not Awaiting Submission,
   link expired based on `CreatedDate`). Returns a `CredentialInfo` wrapper with
   a status code.
4. The LWC state machine transitions to `FORM`, `INVALID_LINK`,
   `ALREADY_SUBMITTED`, or `LINK_EXPIRED` based on the returned status.
5. Volunteer enters `Issued By`, `Expiry Date` (if applicable), and selects
   files using a native `<input type="file">` element. JavaScript reads each
   file as a base64 data URI via `FileReader`.
6. Volunteer clicks Submit. The component re-validates inputs, then calls
   `submitCredential(token, issuedBy, expiryDate)`. Apex re-validates the
   token (second gate prevents replay), updates the existing
   `Credential_Request__c` (sets Status = Pending Review, Issued_By__c,
   Expiry_Date__c), and updates `Credential__c.Status__c` to Under Review.
   Returns the `Credential_Request__c` Id.
7. The component calls `uploadFile(requestId, fileName, base64Data)` once per
   selected file, sequentially. Apex creates a `ContentVersion` per call with
   `FirstPublishLocationId = requestId`; Salesforce auto-creates the
   `ContentDocumentLink`.
8. Component transitions to `SUCCESS` state.

### Volunteer Form Submission (Screen Flow path)

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
