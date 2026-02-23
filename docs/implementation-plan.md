# Implementation Plan

Live master plan for the Credential Intake System build. Update task statuses as work progresses. Note deviations and their reasons as they occur.

**Last updated:** 2026-02-24

---

## Phase 1 - Data Model and Internal Admin Page

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | Create `Credential_Type__c` custom object with Auto-Number Name | done | `CT-{0000}` format. OWD ReadWrite. |
| 1.2 | Add `Type__c` field (Text) to Credential Type | done | Free text - more flexible than picklist for multi-org use. |
| 1.3 | Add `Days_Before_Expiry__c` field (Number) to Credential Type | done | |
| 1.4 | Add `Link_Expiry_Days__c` field (Number, Required) to Credential Type | done | Marked required - a missing value would make expiry logic fail. |
| 1.5 | Add `Does_Not_Expire__c` field (Checkbox) to Credential Type | done | |
| 1.6 | Create `Credential__c` custom object with Auto-Number Name | done | `CR-{0000}` format. OWD Private. History tracking enabled. |
| 1.7 | Add `Credential_Type__c` Lookup field to Credential | done | |
| 1.8 | Add `Account__c` Lookup field to Credential | done | |
| 1.9 | Add `Contact__c` Lookup field to Credential | done | |
| 1.10 | Add `Status__c` Picklist field with values: Draft, Pending, Requested, Under Review, Active, Expired | done | Draft is default. |
| 1.11 | Add `Requested_Date__c` Date/Time field to Credential | done | |
| 1.12 | Add `Issued_By__c` Text field to Credential | done | |
| 1.13 | Add `Expiry_Date__c` Date field to Credential | done | |
| 1.14 | Add `Sighted__c` Checkbox field to Credential | done | `trackHistory=true` set on field. |
| 1.15 | Add `Unique_Token__c` Text field to Credential (hidden from standard layouts) | done | Length 36 (GUID format). Unique=true. Excluded from layout. |
| 1.16 | Add `Submission_Link__c` Formula (Text) field to Credential | done | Contains URL placeholder - update in Phase 2 task 2.5. |
| 1.17 | Add validation rule: block Status = Active if Sighted__c = FALSE | done | Error displayed on Status__c field. Uses ISPICKVAL. |
| 1.18 | Enable Field History Tracking on `Sighted__c` | done | `enableHistory=true` on object, `trackHistory=true` on field. |
| 1.19 | Configure Lightning Record Page for Credential | done | Flexipage with header (highlights), tabs (Details, Activity, Related). |
| 1.20 | Add `Submission_Link__c` to the Highlights Panel | done | `Credential_Highlights` compact layout assigned as default on object. |

---

## Phase 2 - Token and Site Setup

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Build Record-Triggered Flow: generate GUID into `Unique_Token__c` on Credential creation (After Insert) | done | `GenerateUUID` Apex invocable action + `Credential_Token_Generation` After Insert flow. 3/3 Apex tests passing. |
| 2.2 | Build Record-Triggered Flow (Before Update): stamp `Requested_Date__c` when Status changes to "Requested" | done | `Credential_Requested_Date_Stamp` Before Save flow. Decision element guards against re-stamping on re-saves. |
| 2.3 | Create unauthenticated Experience Cloud site | todo | UI task - cannot be created as source metadata from scratch. |
| 2.4 | Configure Guest User Profile: enable "Run Flows", disable all object permissions | todo | UI task - depends on 2.3. |
| 2.5 | Update `Submission_Link__c` formula with the correct Experience Cloud site base URL | done | `https://sl1771816777101.my.site.com/credentials/s/submit?id=` (demo org). |

---

## Phase 3 - Screen Flow Development

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | Create Intake Screen Flow with `id` text input variable | done | `Credential_Intake_Form` Screen Flow. |
| 3.2 | Add SOQL Get Records element: find Credential where `Unique_Token__c = {id}` | done | Two recordLookups: Get_Credential then Get_Credential_Type. |
| 3.3 | Add Decision element: evaluate Invalid Link, Already Submitted, Link Expired, and Success outcomes | done | Three decision gates: Record_Found, Validate_Status, Check_Expiry. isLinkExpired formula variable handles the date arithmetic. |
| 3.4 | Add error screens for each invalid path (Invalid Link, Already Submitted, Link Expired) | done | |
| 3.5 | Add Intake Screen: display Credential Type label, collect Issued By, Expiry Date (conditional), and File Upload | done | Expiry Date hidden via visibilityRule when Does_Not_Expire__c = true. |
| 3.6 | Add File Upload component linked to `ContentDocumentLink` on the Credential record | done | `forceContent:fileUpload` component, accept: .pdf,.jpg,.png, recordId wired to credentialRecord.Id. |
| 3.7 | Add Update Records element: set Status to "Under Review", save Issued_By__c and Expiry_Date__c | done | |
| 3.8 | Set Flow to run in System Context Without Sharing | done | `runInMode: SystemModeWithoutSharing` set on flow. |
| 3.9 | Deploy Intake Flow to the Experience Cloud site page | todo | |
| 3.10 | End-to-end test of the full submission flow in a browser | todo | |

---

---

## Deviations

None recorded yet.

---

## Discovered Work

Items found during implementation that were not in the original spec. Log them here and in `docs/todo.md`.

- None yet.
