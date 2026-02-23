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
