# Solution Overview

## Problem Statement

Volunteer-based organisations need to collect, verify, and track credentials (e.g. Police Checks, Working with Children Checks, Driver's Licences) from their volunteers. Historically this is handled through email and spreadsheets, creating a fragmented audit trail and no clear ownership of the verification process.

This solution provides a secure, admin-controlled intake process where:
- An admin creates a Credential record in Salesforce and sends the volunteer a unique submission link
- The volunteer clicks the link, fills in a simple form, and uploads their document - no Salesforce login required
- The admin reviews the uploaded file, marks it as sighted, and activates the credential

The system enforces time-bound access (the link expires), prevents URL guessing (IDOR protection via GUID token), and keeps all credential data inside Salesforce under private OWD.

---

## Approach

The solution is built entirely on the Salesforce platform using declarative tooling - no custom code, no external services. Key choices:

- **Screen Flow in System Mode** acts as the data proxy for the public-facing form. The Guest User Profile has zero object permissions; the flow itself performs all reads and writes using system context. This avoids granting object access to the internet.
- **Experience Cloud** hosts the public form page on an unauthenticated site. The flow is embedded on this page.
- **GUID tokens** on each Credential record serve as the access key. The submission URL contains only the token; the record ID is never exposed.
- **Link expiry** is enforced inside the flow by comparing today's date against `Requested_Date__c + Link_Expiry_Days__c`.

See `docs/decisions/` for the rationale behind each of these choices.

---

## Key Components

| Component | What it does |
|---|---|
| **Credential Type** object | Master list of document types (e.g. Police Check). Defines expiry notification lead time and link expiry window. |
| **Credential** object | The transaction record linking a person (Contact or Account) to a required document. Tracks status throughout its lifecycle. |
| **Request Creation Flow** | Record-triggered After Update flow that creates a `Credential_Request__c` with a unique token when Credential status moves to "Requested". |
| **Requested Date Flow** | Record-triggered Before Update flow that stamps `Requested_Date__c` when status moves to "Requested". |
| **Intake Screen Flow** | The public-facing form. Validates the token, checks expiry, collects data, and updates the request record. Runs in System Mode Without Sharing. |
| **Experience Cloud Site** | Hosts the Intake Flow on a public, unauthenticated URL. Guest User Profile is locked down to flow execution only. |
| **Scheduled Expiry Flow** | Nightly flow that checks credential expiry dates and updates status to "Expired" as needed. |
| **Validation Rule** | Prevents a Credential from being set to Active unless `Sighted__c` is TRUE. Enforces the verification step. |

---

## Key Flows

### Admin Requests a Credential Submission

1. Admin creates a Credential record, linking it to a Contact or Account and selecting a Credential Type.
2. Admin changes Status to "Requested". The Before Update flow stamps `Requested_Date__c`. The After Update flow creates a `Credential_Request__c` with a unique token and Status = Awaiting Submission.
3. Admin copies the `Submission_Link__c` formula field from the Credential Request Highlights Panel and sends it to the volunteer (email, SMS, etc.).

### Volunteer Submits a Credential

1. Volunteer receives the link and opens it in a browser. The Experience Cloud site loads.
2. The Intake Screen Flow receives the `id` token from the URL.
3. The flow looks up the Credential record by token and evaluates three checks:
   - Is the record found? (Invalid Link path if not)
   - Is the status still "Requested"? (Already Submitted path if not)
   - Has the link expired? (Link Expired path if yes)
4. If all checks pass, the volunteer sees the intake form. They enter their issuer details, expiry date (if applicable), and upload their document (.pdf, .jpg, or .png).
5. On submission, the flow updates the Credential status to "Under Review" and saves the uploaded file as a ContentDocumentLink.
6. A confirmation email is sent to the linked Contact or Account.

### Admin Verifies and Activates

1. Admin receives notification (or checks the queue) and opens the Credential record.
2. Admin reviews the uploaded file and ticks the `Sighted__c` checkbox.
3. Admin changes status to "Active". The validation rule blocks activation if `Sighted__c` is false.
4. Field History Tracking on `Sighted__c` provides an audit trail.

---

## What This Solution Does Not Do

- **Does not authenticate volunteers** - the form is intentionally public and access-controlled via token only
- **Does not send the submission link automatically** - the admin copies and distributes the link manually
- **Does not support credential types that require multiple documents** in a single submission
- **Does not integrate with external verification services** (e.g. third-party background check providers)
- **Does not provide a volunteer-facing portal** for viewing their own submission history

---

## Related Documentation

- [Architecture](architecture.md) - component structure and data flow
- [Data Model](data-model.md) - object schema and field reference
- [Security](security.md) - access control model and trust boundaries
- [Implementation Plan](implementation-plan.md) - phased build plan and current status
- [User Guide](user-guide.md) - guide for admins and volunteers
- [Manual Test Plan](manual-test-plan.md) - test scenarios for QA
- [Decisions](decisions/) - rationale for key design choices
