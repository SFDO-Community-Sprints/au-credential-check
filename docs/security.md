# Security

## Trust Boundaries

The system has two distinct trust zones:

| Zone | Who | Access mechanism |
|---|---|---|
| Internal (Salesforce) | Admins with a Salesforce login | Standard Salesforce authentication and profile/permission set model |
| External (Experience Cloud) | Volunteers with no Salesforce account | GUID token in the submission URL |

Data never moves from the external zone into Salesforce directly. The Intake Screen Flow and `CredentialSubmissionController` Apex class act as controlled proxies - they read and write on behalf of the guest user and only operate on the specific `Credential_Request__c` that matches the submitted token.

---

## Access Control Model

### Internal Users

Standard Salesforce profile and permission set model applies. Admins require:
- Read/Write on `Credential__c`
- Read on `Credential_Type__c`
- Access to the Credentials Lightning App and record pages

OWD (Organisation-Wide Defaults) for `Credential__c` and related files are set to **Private**. This ensures volunteers cannot see each other's records even if they somehow accessed the Experience Cloud site as an authenticated user.

OWD for `Credential_Request__c` is **ReadWrite**. This is acceptable because `Credential_Request__c` is an internal staging object - it is only accessible to logged-in Salesforce users. Volunteers cannot query it directly; they access only through the System Mode Intake Flow. ReadWrite OWD removes the need for manual sharing rules and allows all admins to review and act on any request without additional configuration. See `docs/decisions/use-staging-object-for-intake.md`.

### External Users (Volunteers)

The Guest User Profile for the Experience Cloud site is configured with:
- **Zero object permissions** - no read, create, edit, or delete access to any object
- **Flow access granted per-flow** via the flow's individual access settings (see below)
- No access to any Salesforce data directly

**Guest user flow access:** Salesforce removed the "Run Flows" system permission from Guest User Profiles. Flow access for guest users must now be granted individually per flow. To allow the Intake Screen Flow to run for unauthenticated visitors:

1. Go to **Setup > Flows**.
2. Open the dropdown next to `Credential_Intake_Form` and select **Edit Access**.
3. Change to **"Override default behavior and restrict access to enabled profiles or permission sets"**.
4. Add the site's **Guest User Profile** (e.g. `credentials Profile`) to the Enabled Profiles list.
5. Save.

This must be repeated for any additional flows that need guest access. The `credentialSubmissionForm` LWC calls Apex directly rather than invoking a flow, so no additional flow access is required for the LWC path.

All data access for the form is performed by either the Intake Screen Flow (running in **System Context Without Sharing**) or the `CredentialSubmissionController` Apex class (declared `without sharing`). Both validate the token before reading or writing any data. The Apex class additionally validates the `requestId` parameter before accepting file uploads, preventing files from being attached to arbitrary records.

---

## GUID Token (IDOR Protection)

Each `Credential_Request__c` record has a `Unique_Token__c` field populated at creation by the `Credential_Request_Creation` flow using a GUID (Globally Unique Identifier). This token is:

- Randomly generated - not derived from any record ID or predictable value
- The only identifier embedded in the submission URL
- Checked by the Intake Flow (or Apex controller) before any data is read or written
- Unique to the specific request - a new token is generated each time the Credential is set to Requested

This prevents Insecure Direct Object Reference (IDOR) attacks. An attacker cannot enumerate valid submission URLs by guessing or iterating record IDs.

Neither the `Credential__c.Id` nor the `Credential_Request__c.Id` is included in the submission URL.

---

## Time-Bound Access

Submission links are time-limited. The expiry is calculated from the `Credential_Request__c.CreatedDate` (the moment the request was created when the Credential moved to Requested):

```
TODAY() > CreatedDate.date() + Credential_Type__r.Link_Expiry_Days__c
```

If this condition is true, an "expired" screen is shown and submission is blocked. The window is configured per Credential Type (e.g. 7 days), allowing different expiry periods for different document categories.

This limits the vulnerability window for any compromised or forwarded link.

---

## Data Integrity

### Verification Gating

A validation rule on `Credential__c` blocks the Status from being set to "Active" unless `Sighted__c` is TRUE. This ensures no credential can be activated without an admin reviewing and confirming the uploaded document.

In normal operation, the `Credential_Request_Approval` flow sets both `Sighted__c = true` and `Status__c = Active` in the same DML operation when an admin approves a request, satisfying the validation rule automatically. The rule acts as a safety net against manual edits that would bypass the review step.

### Field History Tracking

`Sighted__c` has Field History Tracking enabled. All changes to this field are recorded with the user, timestamp, and old/new value. This provides an audit trail for credential verification.

---

## Sensitive Fields

| Field | Sensitivity | Handling |
|---|---|---|
| `Credential_Request__c.Unique_Token__c` | High - functions as an access key | Not shown on layouts. Never logged or surfaced in error messages. Displayed only indirectly through the `Submission_Link__c` formula on the same record. |
| `Sighted__c` | Medium - audit-significant | Field History Tracking enabled. Admin-only field. |
| `Status__c` | Medium - lifecycle control | Changes are significant; automated timestamps on key transitions. |
| Uploaded files | High - may contain PII | Stored as Salesforce Files linked to the `Credential_Request__c` staging record. Not attached to the Credential directly. Accessible only to internal users. |

---

## Known Constraints and Considerations

- The submission link itself is not encrypted in transit beyond standard HTTPS. The link should be treated as a credential - whoever holds it can submit to that specific Credential record during the validity window.
- The system does not revoke links automatically when a link is forwarded or shared. Because the token lives on `Credential_Request__c`, an admin can invalidate a link by setting the request Status to Rejected (which blocks the ALREADY_SUBMITTED gate) or by setting the parent Credential Status back to Draft and then to Requested again, which creates a new `Credential_Request__c` with a fresh token.
- Files uploaded via the Guest User context are associated with the guest user in Salesforce's system user model. Confirm that your org's file access policies handle this appropriately.
- The Screen Flow runs Without Sharing and `CredentialSubmissionController` is declared `without sharing`. This is intentional and required for the guest user pattern to work. The tradeoff is documented in `docs/decisions/use-screen-flow-in-system-mode.md` and in the `CredentialSubmissionController` class comment.
