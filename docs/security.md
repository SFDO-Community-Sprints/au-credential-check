# Security

## Trust Boundaries

The system has two distinct trust zones:

| Zone | Who | Access mechanism |
|---|---|---|
| Internal (Salesforce) | Admins with a Salesforce login | Standard Salesforce authentication and profile/permission set model |
| External (Experience Cloud) | Volunteers with no Salesforce account | GUID token in the submission URL |

Data never moves from the external zone into Salesforce directly. The Intake Screen Flow acts as a controlled proxy - it reads and writes on behalf of the guest user using System Mode, and only operates on the specific Credential record that matches the submitted token.

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
- **Run Flows** system permission enabled
- No access to any Salesforce data directly

All data access for the form is performed by the Intake Screen Flow running in **System Context Without Sharing**. The flow validates the token before doing anything, so it acts as a narrow, controlled gate.

---

## GUID Token (IDOR Protection)

Each Credential record has a `Unique_Token__c` field populated at creation by a Record-Triggered Flow using a GUID (Globally Unique Identifier). This token is:

- Randomly generated - not derived from the record ID or any predictable value
- The only identifier embedded in the submission URL
- Checked by the Intake Flow before any data is read or written

This prevents Insecure Direct Object Reference (IDOR) attacks. An attacker cannot enumerate valid submission URLs by guessing or iterating record IDs.

The Salesforce record ID (`Credential__c.Id`) is never included in the submission URL.

---

## Time-Bound Access

Submission links are time-limited. The Intake Flow checks:

```
TODAY() > DateValue(Requested_Date__c) + Credential_Type__r.Link_Expiry_Days__c
```

If this condition is true, the flow shows an "expired" screen and does not proceed. The window is configured per Credential Type (e.g. 7 days), allowing different expiry periods for different document categories.

This limits the vulnerability window for any compromised or forwarded link.

---

## Data Integrity

### Verification Gating

A validation rule on `Credential__c` blocks the Status from being set to "Active" unless `Sighted__c` is TRUE. This ensures no credential can be activated without an admin reviewing and confirming the uploaded document.

### Field History Tracking

`Sighted__c` has Field History Tracking enabled. All changes to this field are recorded with the user, timestamp, and old/new value. This provides an audit trail for credential verification.

---

## Sensitive Fields

| Field | Sensitivity | Handling |
|---|---|---|
| `Unique_Token__c` | High - functions as an access key | Hidden in the UI. Never logged or surfaced in error messages. Displayed only indirectly through the `Submission_Link__c` formula. |
| `Sighted__c` | Medium - audit-significant | Field History Tracking enabled. Admin-only field. |
| `Status__c` | Medium - lifecycle control | Changes are significant; automated timestamps on key transitions. |
| Uploaded files | High - may contain PII | Stored as Salesforce Files linked to the `Credential_Request__c` staging record. Not attached to the Credential directly. Accessible only to internal users. |

---

## Known Constraints and Considerations

- The submission link itself is not encrypted in transit beyond standard HTTPS. The link should be treated as a credential - whoever holds it can submit to that specific Credential record during the validity window.
- The system does not revoke links automatically when a link is forwarded or shared. If a link is compromised, an admin can reset it by changing Status back to Draft and then to Requested, which does not regenerate the GUID but does reset the time window. To fully invalidate a link, the GUID would need to be regenerated manually - consider adding a "Regenerate Token" button (see `docs/todo.md`).
- Files uploaded via the Guest User context are associated with the guest user in Salesforce's system user model. Confirm that your org's file access policies handle this appropriately.
- The Screen Flow runs Without Sharing. This is intentional and required for the guest user pattern to work. The tradeoff is documented in `docs/decisions/use-screen-flow-in-system-mode.md`.
