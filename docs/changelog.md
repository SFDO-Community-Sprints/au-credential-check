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

## 2026-02-24 - Token Ownership Restructure

Moved the GUID token and submission link from `Credential__c` to `Credential_Request__c`.

**Why:** The original design placed `Unique_Token__c` and `Submission_Link__c` on the Credential itself, which meant one fixed token per credential for its lifetime. The Phase 4 staging object introduced `Credential_Request__c` as the per-submission unit, making it the natural owner of the token. With the token on the request, each time an admin reissues a link (by resetting Status to Requested), a new request is created with a new token - old links are invalidated automatically without any additional logic.

**What changed:**
- `Unique_Token__c` (Text 36, Unique) and `Submission_Link__c` (formula) fields added to `Credential_Request__c`.
- `Credential_Request_Creation` After Update flow now calls `GenerateUUID` and stores the result on the new Credential Request record, not on `Credential__c`.
- `CredentialSubmissionController` (LWC Apex controller) updated to query `Credential_Request__c WHERE Unique_Token__c = :token` instead of `Credential__c`. `submitCredential` method now updates the existing request rather than creating a new one.
- `Credential_Request_Approval` flow updated to also set `Sighted__c = true` and `Status__c = Active` on the linked Credential when approving (required by the `Block_Activation_Without_Sighting` validation rule, which prevents Status = Active if Sighted is false).

**Deferred cleanup:**
- `Credential__c.Unique_Token__c` and `Credential__c.Submission_Link__c` still exist in the org because the legacy `Credential_Intake_Form` screen flow references them. They cannot be deleted until that flow is updated. Documented in `docs/todo.md` and `manifest/destructiveChangesPost.xml`.
- The `Credential_Token_Generation` After Insert flow (which populated the old `Credential__c.Unique_Token__c`) could not be deactivated and deleted - it is active with references that prevent removal. Left in place pending screen flow update.

---

## 2026-02-24 - Phase 5: LWC Alternative Submission Component

Added a Lightning Web Component implementation of the credential intake form as an alternative to the Phase 3 Screen Flow. Targets LWR-based Experience Cloud sites where the screen flow may not be deployable. Both implementations coexist; neither replaces the other.

**Why:** The Screen Flow runs in System Mode Without Sharing but relies on Salesforce Flow infrastructure and cannot be customised beyond what Flow components allow. An LWC provides the same behaviour as reusable component code with full control over layout, validation, and error handling.

**What was added:**
- New Apex class: `CredentialSubmissionController` (without sharing). Three `@AuraEnabled` methods: `getCredentialByToken` (validates token against `Credential_Request__c`, returns state machine status code), `submitCredential` (re-validates token, updates existing request to Pending Review, updates Credential to Under Review), `uploadFile` (creates ContentVersion via base64 decode, validates requestId before accepting files).
- New Apex test class: `CredentialSubmissionControllerTest`. 8 test methods covering all validation paths and happy paths for all three methods. Hard-coded UUID-format tokens on `Credential_Request__c` records; `Link_Expiry_Days__c = -1` trick for expired link scenario.
- New LWC: `credentialSubmissionForm`. 7-state state machine (LOADING, INVALID_LINK, ALREADY_SUBMITTED, LINK_EXPIRED, FORM, SUBMITTING, SUCCESS). Reads token via `@wire(CurrentPageReference)`. File upload uses native `<input type="file">` with FileReader base64 encoding. Sequential per-file Apex calls to stay within heap limits. Targets `lightningCommunity__Page` and `lightningCommunity__Default`.

**Key design decisions:**
- Files uploaded as base64 via Apex to avoid guest user file upload permission complications on LWR sites.
- Collect-then-submit: volunteer fills out the full form before clicking Submit. No orphan `Credential_Request__c` records if the user abandons mid-form (the LWC does not pre-create the request before the form renders, unlike the Screen Flow).
- Token re-validated server-side on submit to prevent replay attacks where the link expires between page load and form submit.

---

## 2026-02-24 - Phase 4: Staging Object and Review Gate

Introduced `Credential_Request__c` as a staging layer between volunteer form submission and the authoritative `Credential__c` record.

**Why:** The original Phase 3 design wrote volunteer-submitted data (Issued By, Expiry Date, file) directly onto the Credential record in a single step. This meant unverified data from an unauthenticated external submission immediately became part of the official credential record with no review gate. The staging object separates unverified intake data from the authoritative record, adds an admin review step, and preserves the original submission as an audit trail.

**What changed:**
- New object: `Credential_Request__c` (OWD ReadWrite, Auto-Number CRQ-{0000}). Fields: Credential lookup, Status picklist (Awaiting Submission / Pending Review / Approved / Rejected), Issued By, Expiry Date.
- New flow: `Credential_Request_Creation` - After Update flow on Credential. Fires when Status moves to Requested; calls `GenerateUUID` Apex action and creates a `Credential_Request__c` with Status = Awaiting Submission and a fresh UUID token.
- New flow: `Credential_Request_Approval` - After Save record-triggered flow on Credential Request. Fires when Status changes to Approved; copies Issued By and Expiry Date to the linked Credential and sets Status = Active and Sighted = true.
- Rewritten: `Credential_Intake_Form` flow - now creates a Credential Request before rendering the intake screen (so the file upload component has a recordId), writes submitted data to the staging record, and only updates the Credential Status to Under Review.
- Updated: Credential layout now shows a Credential Requests related list.

**Trade-offs accepted:**
- If a volunteer abandons the form after the pre-screen staging record creation (Screen Flow path only), an empty `Credential_Request__c` record will exist. This is accepted in favour of correct file attachment behaviour. The LWC path does not have this issue.
- Files stay on `Credential_Request__c` only; they are never moved to the Credential record.

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
