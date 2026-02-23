# Implementation Plan

Live master plan for the Credential Intake System build. Update task statuses as work progresses. Note deviations and their reasons as they occur.

**Last updated:** 2026-02-24 (Phase 4 added)

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

### Manual steps - Phase 1

**1-M1 - Assign the Credential Record Page as default** `todo`

The `Credential_Record` Lightning Record Page was deployed via metadata but needs to be explicitly activated as the default for the org.

1. Go to **Setup > Object Manager > Credential > Lightning Record Pages**.
2. Click **Credential Record** in the list.
3. Click **Activation**.
4. Set as the **Org Default** for the record page.
5. Save.

**1-M2 - Add Credential tabs to a Lightning App** `todo`

The Credential and Credential Type tabs were deployed but are not visible in any app until added manually.

1. Go to **Setup > App Manager**.
2. Open the app admins will use to manage credentials (e.g. Sales, or a custom app).
3. Click **Edit**.
4. Under **Navigation Items**, add **Credentials** and **Credential Types** to the Selected Items list.
5. Save.

---

## Phase 2 - Token and Site Setup

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Build Record-Triggered Flow: generate GUID into `Unique_Token__c` on Credential creation (After Insert) | done | `GenerateUUID` Apex invocable action + `Credential_Token_Generation` After Insert flow. 3/3 Apex tests passing. |
| 2.2 | Build Record-Triggered Flow (Before Update): stamp `Requested_Date__c` when Status changes to "Requested" | done | `Credential_Requested_Date_Stamp` Before Save flow. Decision element guards against re-stamping on re-saves. |
| 2.3 | Create unauthenticated Experience Cloud site | done | Site exists at `https://sl1771816777101.my.site.com/credentials`. |
| 2.4 | Configure Guest User access to the Intake Flow and confirm zero object permissions | todo | UI task - see manual steps below. |
| 2.5 | Update `Submission_Link__c` formula with the correct Experience Cloud site base URL | done | `https://sl1771816777101.my.site.com/credentials/s/submit?id=` (demo org). |

### Manual steps - Phase 2

**2-M1 - Grant the Guest User access to the Intake Flow** `todo`

Salesforce removed the "Run Flows" system permission from Guest User Profiles in Spring '23. Access is now granted per-flow individually via the flow's own access settings.

1. Go to **Setup > Flows**.
2. Find **Credential - Intake Form** in the list.
3. Click the dropdown arrow next to the flow and select **Edit Access**.
4. Change the setting to **"Override default behavior and restrict access to enabled profiles or permission sets"**.
5. In the Enabled Profiles list, add the **Guest User Profile** for the credentials site (named something like `credentials Profile`).
6. Save.

**2-M2 - Confirm Guest User Profile has no object permissions** `todo`

The flow runs in System Mode Without Sharing and handles all data access itself. The Guest User Profile must have no object access.

1. Go to **Setup > Digital Experiences > All Sites**.
2. Click **Workspaces** next to the credentials site, then **Administration > Pages > Go to Experience Builder**.
3. In Experience Builder, click the **gear icon > General** and click the **Guest User Profile** link.
4. Under **Object Settings**, confirm that `Credential__c` and `Credential_Type__c` have **no** read, create, edit, or delete permissions.
5. Save if any changes were needed.

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
| 3.9 | Deploy Intake Flow to the Experience Cloud site page | todo | UI task - see manual steps below. |
| 3.10 | End-to-end test of the full submission flow in a browser | todo | See manual steps below. |

### Manual steps - Phase 3

**3-M1 - Create the submit page in Experience Builder** `todo`

The `Submission_Link__c` formula points to `/s/submit`. This page must exist in the site and be accessible to guest users.

1. Go to **Setup > Digital Experiences > All Sites**.
2. Click **Workspaces** next to the credentials site, then open **Experience Builder**.
3. Click **New Page** > **Standard Page**.
4. Set the page name to `Submit` and the URL to `submit`. The full path will be `/s/submit`.
5. Select a blank layout.
6. Save.

**3-M2 - Add the Intake Flow to the submit page** `todo`

1. On the `submit` page in Experience Builder, click **Components** in the left panel.
2. Drag a **Flow** component onto the page canvas.
3. In the component properties panel on the right, set **Flow** to `Credential - Intake Form`.
4. Under **Flow Input Variables**, map the `id` input variable to the URL query parameter `id`. Set the source to **URL Parameter** and the parameter name to `id`.
5. Save the page.

**3-M3 - Set page visibility to public and publish** `todo`

1. On the submit page, click the **gear icon** > **Page Access**.
2. Confirm access is set to **Public - accessible to guest users**.
3. Click **Publish** (top right) to push all Experience Builder changes live.

**3-M4 - End-to-end test** `todo`

Full walkthrough to verify the system works before signing off. Run after all manual steps above are complete.

1. In the org, create a **Credential Type** record:
   - Type: `Police Check`
   - Link Expiry Days: `7`
   - Does Not Expire: unchecked
2. Create a **Credential** record:
   - Credential Type: the record created above
   - Leave Status as `Draft`
   - Save and confirm `Unique_Token__c` is populated (visible in field history or via SOQL).
3. Change Status to `Requested` and save. Confirm `Requested_Date__c` is stamped.
4. On the Highlights Panel, copy the **Submission Link** value.
5. Open the link in an **incognito/private browser window** (to simulate the guest user experience). Confirm the intake form loads.
6. Fill in **Issued By**, set an **Expiry Date**, and upload a `.pdf` file. Click **Submit**.
7. Confirm the success screen is shown.
8. Back in the org, open the Credential record and confirm:
   - Status is `Under Review`
   - `Issued_By__c` and `Expiry_Date__c` are populated
   - A file is visible in the Files related list
9. Test invalid paths in a browser:
   - Open the submission link again - confirm "Already Submitted" screen.
   - Manually construct a URL with a fake token - confirm "Invalid Link" screen.

---

---

## Phase 4 - Staging Object and Review Gate

Introduces `Credential_Request__c` as a staging layer between volunteer submission and the authoritative `Credential__c` record. Unverified data no longer writes directly to the credential; it lands on the request staging record and is only promoted after admin approval. See `docs/decisions/use-staging-object-for-intake.md`.

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | Create `Credential_Request__c` custom object (Auto-Number CRQ-{0000}, OWD ReadWrite) | done | |
| 4.2 | Add `Credential__c` Lookup field to Credential Request (required, deleteConstraint: Restrict) | done | |
| 4.3 | Add `Status__c` Picklist field (Pending Review default, Approved, Rejected) | done | Restricted picklist - approval flow checks for exact "Approved" value. |
| 4.4 | Add `Issued_By__c` Text (255) field to Credential Request | done | Not required - field may be blank if volunteer abandons after staging record is created. |
| 4.5 | Add `Expiry_Date__c` Date field to Credential Request | done | Not required - blank is correct for non-expiring credential types. |
| 4.6 | Create compact layout `Credential_Request_Highlights` | done | Fields: Name, Status__c, Credential__c, Issued_By__c, Expiry_Date__c. |
| 4.7 | Create standard layout for Credential Request | done | Status is editable (admin action); Issued_By and Expiry_Date are read-only to preserve submission integrity. |
| 4.8 | Build `Credential_Request_Approval` record-triggered flow (After Save, Update) | done | Fires on Status = Approved. Guards against re-fire on re-saves. Copies Issued_By and Expiry_Date to linked Credential. |
| 4.9 | Rewrite `Credential_Intake_Form` flow to create staging record before screen, wire file upload to it, update staging record after submission, and strip Issued_By/Expiry_Date from Update_Credential | done | Staging record must be created before the screen renders - file upload component needs a recordId at load time. Empty staging records may exist if a volunteer abandons after the pre-screen create step. |
| 4.10 | Add Credential Requests related list to Credential layout | done | Allows admins to navigate directly from the Credential record to linked requests. |
| 4.11 | Deploy to `jerry@credentials.sfdo` and run end-to-end verification | todo | See manual steps below. |

### Manual steps - Phase 4

**4-M1 - End-to-end verification** `todo`

1. In the org, create a **Credential Type** and **Credential** record (or use existing ones).
2. Set the Credential Status to `Requested`. Copy the Submission Link.
3. Open the link in an incognito browser. Submit the form with an Issued By value, an Expiry Date, and an uploaded file.
4. Confirm:
   - A `Credential_Request__c` record was created with Status = Pending Review and correct Issued By / Expiry Date values.
   - The uploaded file appears on the Credential Request Files related list.
   - The `Credential__c` Status = Under Review and `Issued_By__c` / `Expiry_Date__c` are **blank**.
5. On the Credential Request record, change Status to **Approved**.
6. Confirm:
   - The approval flow fired.
   - `Credential__c.Issued_By__c` and `Credential__c.Expiry_Date__c` are now populated with the submitted values.

---

## Deviations

None recorded yet.

---

## Discovered Work

Items found during implementation that were not in the original spec. Log them here and in `docs/todo.md`.

- None yet.
