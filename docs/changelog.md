# Changelog

Human-readable log of meaningful changes to the project. Focuses on decisions and intent, not a repeat of git commit messages.

---

## 2026-02-23 - Project Specification and Documentation

Completed the full project specification for the Credential Intake System. Defined the data model (Credential Type and Credential objects), the security framework (GUID token, system mode flow, OWD private, link expiry), and the phased implementation plan.

All core documentation written and committed:
- Solution overview, user guide, architecture, data model, security, implementation plan, test plan, testing strategy, environment setup.
- Decision records for the three key design choices: Screen Flow in System Mode, GUID tokens, and Experience Cloud.

Implementation has not yet started. All tasks in the implementation plan are at "todo" status.

---

## 2026-02-24 - Phase 4: Staging Object and Review Gate

Introduced `Credential_Request__c` as a staging layer between volunteer form submission and the authoritative `Credential__c` record.

**Why:** The original Phase 3 design wrote volunteer-submitted data (Issued By, Expiry Date, file) directly onto the Credential record in a single step. This meant unverified data from an unauthenticated external submission immediately became part of the official credential record with no review gate. The staging object separates unverified intake data from the authoritative record, adds an admin review step, and preserves the original submission as an audit trail.

**What changed:**
- New object: `Credential_Request__c` (OWD ReadWrite, Auto-Number CRQ-{0000}). Fields: Credential lookup, Status picklist (Pending Review/Approved/Rejected), Issued By, Expiry Date.
- New flow: `Credential_Request_Approval` - After Save record-triggered flow on Credential Request. Fires when Status changes to Approved; copies Issued By and Expiry Date to the linked Credential record.
- Rewritten: `Credential_Intake_Form` flow - now creates a Credential Request before rendering the intake screen (so the file upload component has a recordId), writes submitted data to the staging record, and only updates the Credential Status to Under Review (not the field values).
- Updated: Credential layout now shows a Credential Requests related list.

**Trade-offs accepted:**
- If a volunteer abandons the form after the pre-screen staging record creation, an empty Credential_Request__c record will exist. This is accepted in favour of correct file attachment behaviour.
- Files stay on Credential_Request__c only; they are never moved to the Credential record.

See `docs/decisions/use-staging-object-for-intake.md`.

---

## 2026-02-23 - Phase 1 Complete: Data Model and Admin UI

All Phase 1 tasks are done and committed as SFDX source metadata.

**Objects created:**
- `Credential_Type__c` - master configuration object. Auto-Number `CT-{0000}`. OWD ReadWrite.
- `Credential__c` - transaction object. Auto-Number `CR-{0000}`. OWD Private. Field History Tracking enabled.

**Fields created:** 4 on Credential Type, 11 on Credential (including the GUID token field, formula link, and all volunteer-entered fields).

**Validation rule:** `Block_Activation_Without_Sighting` - blocks Status = Active when Sighted__c is false.

**UI metadata:** Standard layouts for both objects, compact layouts (Credential highlights panel includes Submission_Link__c), tabs for both objects, Lightning Record Page flexipage for Credential.

**Notable decisions made during build:**
- `Type__c` on Credential Type was implemented as free Text rather than Picklist to give maximum flexibility across different orgs without requiring setup of picklist values.
- `Submission_Link__c` is a Text formula (not URL type) for broadest compatibility. Contains a placeholder URL - update in Phase 2 task 2.5 after the Experience Cloud site is provisioned.
- `Link_Expiry_Days__c` was marked Required (spec did not specify) because a null value would cause the expiry formula in the Intake Flow to behave unpredictably.

---
