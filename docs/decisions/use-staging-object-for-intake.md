# Decision: Use a Staging Object for Volunteer Intake

**Date:** 2026-02-24
**Status:** Accepted

---

## Context

The original Phase 3 design had the Intake Screen Flow write volunteer-submitted data (Issued_By__c, Expiry_Date__c, and the uploaded file) directly onto the `Credential__c` record in a single step.

This design had two problems:

1. **No review gate.** Unverified data from an unauthenticated external submission immediately became part of the authoritative credential record. An admin had to actively undo or overwrite a bad submission rather than simply reject a pending request.

2. **File attachment coupling.** The Salesforce file upload component (`forceContent:fileUpload`) requires a `recordId` at screen load time - it cannot receive one generated after submission. Attaching the file to the Credential record also meant unverified documents were mixed with verified ones on the same record.

---

## Decision

Introduce `Credential_Request__c` as a staging object. The volunteer's form submission creates a Credential Request. An admin reviews it and changes Status to Approved or Rejected. On Approved, a record-triggered flow (`Credential_Request_Approval`) copies the verified field values to the `Credential__c` record.

Files attach to and remain on the `Credential_Request__c` record permanently. They are never moved to `Credential__c`.

---

## Alternatives Considered

### 1. Direct write with a "verified" flag

Add a boolean `Volunteer_Data_Verified__c` flag to `Credential__c` and keep the direct-write approach. An admin would review and tick the flag.

Rejected because: this does not prevent the unverified data from being visible on the credential record, does not provide a natural place to store the original submission separately from the final verified values, and mixing unverified and verified data on the same record creates confusion.

### 2. Approval Process on Credential__c

Use a standard Salesforce Approval Process on `Credential__c` to gate the status transition.

Rejected because: Approval Processes are more complex to configure, are UI-centric (not suitable for headless or programmatic workflows), do not natively distinguish between "the volunteer submitted data" and "the admin approved that data", and would not solve the file attachment problem.

### 3. Keep direct write, lock fields after verification

Write volunteer data directly to the credential, then use validation rules or page layouts to make those fields read-only once Status advances beyond Under Review.

Rejected because: this still has no review gate before the data reaches the credential, does not preserve the original submission separately, and locking fields via layout is UI-only and can be bypassed via API.

---

## Consequences

### Positive

- Admins get a clear review gate before any submission data reaches the authoritative credential record.
- The original submission is preserved as an immutable audit trail on the Credential Request record.
- Files stay with the submission context (the request) rather than on the credential.
- The Intake Flow is simpler in one sense: Update_Credential only writes Status__c, so it cannot corrupt field data even if called unexpectedly.

### Negative / Trade-offs

- **Orphan staging records.** The Credential Request is created before the intake screen renders (so the file upload component has a recordId). If a volunteer abandons the form after that point, an empty Credential_Request__c record exists with no submitted data and no file. These orphans are harmless but administrators should be aware they may appear in list views. A future cleanup job could remove empty abandoned requests (see `docs/todo.md`).
- **Slightly more complex flow.** The Intake Flow now has two additional elements (Create_Credential_Request and Update_Credential_Request) and one more variable (credentialRequestId).
- **Two steps for admin.** Admins must navigate to the Credential Request to approve, rather than editing the Credential directly. The related list on the Credential layout makes this one click.

---

## Implementation Notes

- `Credential_Request__c` OWD is ReadWrite. This is acceptable because the object is internal-only. Volunteers cannot query it via any exposed interface. See `docs/security.md`.
- The `Status__c` picklist on Credential Request uses `<restricted>true</restricted>` to prevent free-text entry. The approval flow checks for the exact string "Approved" - a non-restricted picklist could allow typos that would silently skip the approval logic.
- `deleteConstraint: Restrict` on the Credential lookup prevents a Credential being deleted while requests are linked, preserving the audit trail.
