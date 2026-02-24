# Architecture

## Overview

CredentialsCheck is a Salesforce-native credential intake and verification system. It is built on custom objects, record-triggered flows, Apex classes, and an Experience Cloud site. The submission layer has two parallel implementations: the original Intake Screen Flow and a Lightning Web Component (LWC) alternative for LWR-based Experience Cloud sites.

---

## Package Structure

| Directory | Purpose |
|---|---|
| `force-app/main/default/` | All Salesforce metadata - objects, flows, classes, components, etc. |
| `config/` | Scratch org definition files |
| `scripts/` | Developer utility scripts (SOQL queries, anonymous Apex) |
| `docs/` | Project documentation |

---

## API Version

Currently targeting **API v65.0**. Update `sourceApiVersion` in `sfdx-project.json` when upgrading.

---

## Component Map

```
+-------------------------------------------------------------+
|                      Salesforce Org                         |
|                                                             |
|  +-------------------+    +------------------------------+  |
|  |  Credential Type  |<---|         Credential           |  |
|  |  (Master Object)  |    |    (Transaction Object)      |  |
|  +-------------------+    +--------------+---------------+  |
|                                          |                  |
|                           +--------------v--------------+   |
|                           |    Record-Triggered Flows   |   |
|                           |    - Request Creation       |   |
|                           |      (calls GenerateUUID    |   |
|                           |       Apex invocable)       |   |
|                           |    - Requested Date Stamp   |   |
|                           +-----------------------------+   |
|                                          |                  |
|                           +--------------v--------------+   |
|                           |    Credential Request        |   |
|                           |    (Staging Object)          |   |
|                           |    Unique_Token__c + Link    |   |
|                           +--------------+--------------+   |
|                                          |                  |
|                           +--------------v--------------+   |
|                           |  Credential_Request_Approval |   |
|                           |  (Record-Triggered Flow)     |   |
|                           |  On Status = Approved:       |   |
|                           |  - Copies Issued By + Expiry |   |
|                           |    to linked Credential       |   |
|                           |  - Sets Sighted = true       |   |
|                           |  - Sets Status = Active      |   |
|                           +-----------------------------+   |
|                                                             |
|  +-----------------------------------------------------+    |
|  |        Scheduled Flow (Nightly) - NOT YET BUILT     |    |
|  |  Checks Expiry_Date__c, updates Status__c           |    |
|  |  See docs/todo.md                                   |    |
|  +-----------------------------------------------------+    |
|                                                             |
|  +-----------------------------------------------------+    |
|  |           Experience Cloud Site (Public)            |    |
|  |  +-------------------------------------------+     |    |
|  |  |  Intake Screen Flow (System Mode)          |     |    |
|  |  |  - Receives token from URL (?id=)          |     |    |
|  |  |  - Queries Credential_Request__c by token  |     |    |
|  |  |  - Validates status and expiry             |     |    |
|  |  |  - Collects volunteer input                |     |    |
|  |  |  - Attaches file to Credential Request     |     |    |
|  |  |  - Updates Credential to Under Review      |     |    |
|  |  |  NOTE: pending update - see docs/todo.md   |     |    |
|  |  +-------------------------------------------+     |    |
|  |                                                     |    |
|  |  +-------------------------------------------+     |    |
|  |  |  credentialSubmissionForm LWC (LWR)        |     |    |
|  |  |  - Reads ?id= via CurrentPageReference     |     |    |
|  |  |  - Validates token via Apex (imperative)   |     |    |
|  |  |  - Collects volunteer input                |     |    |
|  |  |  - Uploads files as base64 via Apex        |     |    |
|  |  |  - Same Credential_Request__c outcome      |     |    |
|  |  +-------------------------------------------+     |    |
|  |                    Both backed by                   |    |
|  |  +-------------------------------------------+     |    |
|  |  |  CredentialSubmissionController (Apex)     |     |    |
|  |  |  without sharing - guest user data proxy   |     |    |
|  |  |  getCredentialByToken / submitCredential / |     |    |
|  |  |  uploadFile                                |     |    |
|  |  +-------------------------------------------+     |    |
|  +-----------------------------------------------------+    |
+-------------------------------------------------------------+
```

---

## Data Flow

### Submission Link Creation

1. Admin creates `Credential__c` record (Status = Draft).
2. Admin changes Status to Requested.
3. `Credential_Requested_Date_Stamp` flow (Before Update) stamps `Requested_Date__c` on the Credential.
4. `Credential_Request_Creation` flow (After Update) calls the `GenerateUUID` Apex invocable action to create a cryptographically random UUID, then creates a `Credential_Request__c` with that token in `Unique_Token__c` and Status = Awaiting Submission.
5. `Submission_Link__c` formula field on the Credential Request assembles the public URL from the token.
6. Admin opens the Credential Request from the Credential Requests related list on the Credential record.
7. Admin copies `Submission_Link__c` from the Credential Request highlights panel and sends it to the volunteer.

### Volunteer Form Submission - LWC Path

The LWC path is the primary implementation for LWR Experience Cloud sites.

1. Volunteer opens the URL. LWR Experience Cloud loads the `credentialSubmissionForm` component.
2. `@wire(CurrentPageReference)` delivers the page reference; the component extracts the `id` query parameter as the token.
3. Component calls `CredentialSubmissionController.getCredentialByToken(token)` imperatively. Apex queries `Credential_Request__c WHERE Unique_Token__c = :token` and evaluates three gates:
   - No request found -> returns status `INVALID_LINK`.
   - Request `Status__c != 'Awaiting Submission'` -> returns status `ALREADY_SUBMITTED`.
   - `Date.today() > request.CreatedDate.date() + Link_Expiry_Days__c` -> returns status `LINK_EXPIRED`.
4. The LWC state machine transitions to `FORM`, `INVALID_LINK`, `ALREADY_SUBMITTED`, or `LINK_EXPIRED` based on the returned status.
5. Volunteer enters Issued By, Expiry Date (if applicable), and selects files using a native `<input type="file">` element. JavaScript reads each file as a base64 data URI via `FileReader`.
6. Volunteer clicks Submit. Component re-validates inputs, then calls `submitCredential(token, issuedBy, expiryDate)`. Apex re-validates the token (prevents replay if link expires between page load and submit), updates the `Credential_Request__c` (Status = Pending Review, Issued_By__c, Expiry_Date__c), and updates `Credential__c.Status__c` to Under Review. Returns the `Credential_Request__c` Id.
7. Component calls `uploadFile(requestId, fileName, base64Data)` once per selected file, sequentially (not parallel - avoids Apex heap pressure). Apex creates a `ContentVersion` per call with `FirstPublishLocationId = requestId`; Salesforce auto-creates the `ContentDocumentLink`.
8. Component transitions to `SUCCESS` state.

### Volunteer Form Submission - Screen Flow Path

The original implementation. Pending update to query `Credential_Request__c` by token (currently queries `Credential__c` - see `docs/todo.md`).

1. Volunteer opens the URL. Experience Cloud loads and passes the `id` query parameter to the Intake Screen Flow.
2. Flow performs a SOQL query on `Credential__c WHERE Unique_Token__c = :id`. **Note:** this is the pre-restructure behaviour - the flow needs updating to query `Credential_Request__c` instead.
3. Flow evaluates Decision elements for Invalid Link, Already Submitted, and Link Expired paths.
4. On success path: flow creates a `Credential_Request__c` staging record before the screen renders (the file upload component requires a `recordId` at load time).
5. Flow displays the intake screen; volunteer enters data and uploads a file.
6. Flow writes submitted data to the `Credential_Request__c` and updates `Credential__c.Status__c` to Under Review.

### Admin Review and Approval

1. Admin opens the Credential record and navigates to the Credential Requests related list.
2. Admin opens the `Credential_Request__c` record with Status = Pending Review to review submitted data and attached file.
3. Admin changes `Status__c` to Approved (or Rejected).
4. On Approved: `Credential_Request_Approval` (record-triggered After Update flow) fires.
   - Guards against re-fire: checks `$Record__Prior.Status__c != 'Approved'`.
   - Writes `Issued_By__c` and `Expiry_Date__c` from the request to the linked `Credential__c`.
   - Sets `Credential__c.Sighted__c = true` and `Credential__c.Status__c = 'Active'` in a single DML operation (required to satisfy the Block_Activation_Without_Sighting validation rule).
5. Files stay on `Credential_Request__c` permanently as an audit trail.

### Nightly Expiry Check (not yet built)

1. Scheduled Flow would run each night.
2. Queries `Credential__c` records where `Status__c = 'Active'` and `Expiry_Date__c <= TODAY()`.
3. Batch-updates `Status__c` to Expired.

See `docs/todo.md` for the outstanding task.

---

## External Dependencies

| Dependency | Purpose |
|---|---|
| Experience Cloud | Hosts the public-facing form page |
| Salesforce Files (ContentDocument / ContentVersion) | Stores uploaded credential documents |
| Standard Email (Salesforce Email Actions) | Sends submission confirmation to Contact/Account (not yet configured - see `docs/todo.md`) |

---

## Key Boundaries and Interfaces

- The only public interface is the Experience Cloud site URL with a `?id=` query parameter containing the GUID token.
- The Intake Flow and `CredentialSubmissionController` are the only mechanisms that read or write data on behalf of external users. No other entry point should be available to the Guest User.
- `CredentialSubmissionController` is `without sharing` intentionally - the guest user has no object permissions. The class acts as a narrow, controlled data proxy. All token validation happens inside the class before any data is read or written.
- Internal admins interact with Credential records only through standard Lightning record pages.

---

## Development Model

Source-driven development using Salesforce DX. All changes are tracked as source metadata and deployed via `sf project deploy start`. See `docs/environment.md` for setup steps.
