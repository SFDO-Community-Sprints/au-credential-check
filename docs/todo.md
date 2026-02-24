# TODO

Ongoing tasks and known gaps. Add items here rather than leaving TODOs scattered in code. Stay focused on the current task - capture out-of-scope items here to revisit later.

---

## Pending

### Infrastructure
- Confirm Experience Cloud licence is available in the target org before starting Phase 2.
- Define scratch org shape in `config/project-scratch-def.json` - add Experience Cloud feature flag and confirm other required features.
- Configure CI/CD pipeline for automated deployments.

### Data Model
- Add a validation rule enforcing that at least one of Contact or Account is populated on a Credential record. Currently not enforced declaratively.
- Confirm whether `Credential_Request__c.Unique_Token__c` needs to be an Encrypted field (rather than plain Text) to prevent it appearing in debug logs or SOQL query results.

### Screen Flow
- Update `Credential_Intake_Form` screen flow to query `Credential_Request__c WHERE Unique_Token__c = :id` instead of `Credential__c WHERE Unique_Token__c = :id`. The token was moved to `Credential_Request__c` in the phase-4 restructure; the screen flow will fail at runtime until it is updated. This is a UI change done via Flow Builder in Setup.
- Once `Credential_Intake_Form` is updated, delete the now-redundant `Credential__c.Unique_Token__c` and `Credential__c.Submission_Link__c` fields (they cannot be deleted while the flow references them). Also deactivate and delete the legacy `Credential_Token_Generation` After Insert flow (which populated the old `Credential__c.Unique_Token__c` field).

### Cleanup
- `manifest/destructiveChangesPost.xml` documents the three items blocked from deletion: `Credential__c.Unique_Token__c`, `Credential__c.Submission_Link__c`, and `Credential_Token_Generation` flow. Once the `Credential_Intake_Form` screen flow is updated and the references removed, redeploy the destructive changes manifest to remove these artefacts from the org.

### Security
- Add a "Regenerate Token" action on the Credential record page. Currently, if a submission link is compromised, there is no way to invalidate it other than changing the Status (which resets the time window but not the token). A button that triggers a flow to regenerate `Unique_Token__c` would allow full revocation.
- Review Experience Cloud security checklist (CSP headers, clickjacking protection) before go-live.
- Confirm how files uploaded by the guest user are associated in Salesforce's file ownership model and whether this affects access controls.

### Flow
- Rate limiting on the intake form is not implemented. If abuse is a concern, consider adding an Apex invocable action to detect and reject repeated invalid token attempts from the same IP.

### Future Features
- **Multi-credential submission form**: Allow a volunteer to submit multiple credential types in a single form session. Currently each `Credential_Request__c` has its own unique link and the volunteer must open a separate URL per credential. A combined form would accept multiple tokens (or a single batch token), display all outstanding requests for that volunteer, and let them fill in and upload documents for each in one visit. Requires data model changes to support a batch request concept and rework of the LWC and Apex controller.
- **Bulk request dispatch**: Allow an admin to select multiple `Credential__c` records (e.g. from a list view) and trigger the Requested status change in bulk. Currently each credential must be updated individually. Could be implemented as a List View Button invoking a Flow or Apex, or via a Batch Apex job. Should generate one `Credential_Request__c` per credential (the existing flow handles this per-record) and ideally trigger an email to each linked Contact or Account with their individual submission link.
- **Per-credential-type form fields**: Allow different `Credential_Type__c` records to collect different fields on the submission form. Currently the form always shows the same fields (Issued By, Expiry Date). Some credential types may need additional inputs (e.g. licence number, issuing state, reference number). Salesforce Field Sets are a strong candidate - define a field set per credential type on `Credential_Request__c`, then have the LWC and Apex controller read the field set dynamically via `Schema.FieldSet` and render the appropriate inputs. Requires rework of the LWC to support dynamic field rendering and Apex to read and validate field set members.
- **Agentforce automated document verification**: Use an Agentforce agent to review uploaded credential attachments and verify that the submitted field values (e.g. Issued By, Expiry Date, licence number) match the document contents. The agent would be triggered when a `Credential_Request__c` moves to Pending Review, extract data from the uploaded file using document AI, compare it against the submitted fields, and flag discrepancies for the admin or auto-approve if confidence is high. Would reduce manual review time and catch data entry errors or fraudulent submissions.
- **Automated renewal reminders**: When an Active credential is within `Days_Before_Expiry__c` days of its `Expiry_Date__c`, automatically send a renewal request to the volunteer and create a new `Credential_Request__c` with a fresh submission link. The `Days_Before_Expiry__c` field already exists on `Credential_Type__c` to configure the lead time per document type. Implementation would require: (1) a nightly Scheduled Flow querying Active credentials approaching expiry, (2) email templates per `Credential_Type__c` (or a default template) containing the new submission link, (3) a configurable recipient list per credential type - e.g. the linked Contact email, Account email, or a fixed admin address - stored on `Credential_Type__c` as a formula or related object. The reminder should trigger the same Status-to-Requested transition that generates a new `Credential_Request__c`, so the existing flow handles token creation. Consider whether a single reminder or a series (e.g. 30 days, 7 days, 1 day) is needed, and whether reminders should stop once the volunteer submits.
- **Direct agency API integration for credential verification**: Integrate with issuing authority APIs to verify credentials at source rather than relying on volunteer-supplied documents. Examples: VicRoads API for Victoria driver licences, Australian government document verification service (DVS) for passports and identity documents, WWCC checking services for Working With Children Checks. Each integration would be modelled as a verification action on `Credential_Type__c` - configurable per type so only supported credential types trigger an API call. Results would be written back to `Credential_Request__c` and could auto-approve or flag for manual review. Requires external credential management and callout permissions.

### Automation (Future Phase)
- Build Scheduled Flow: nightly query of `Active` credentials where `Expiry_Date__c < TODAY()` and bulk-update Status to `Expired`. Without this, expired credentials silently remain Active.
- Build submission confirmation email: trigger on Status change to `Under Review`, send to the linked Contact or Account. Volunteer currently gets no acknowledgement after submitting.
- Configure email template for submission confirmation. Decide delivery mechanism - Flow Email Action, Email Alert, or template-based send. Confirm sender address.
- Consider whether renewal notification emails (using `Days_Before_Expiry__c` as lead time) should be added to the Scheduled Flow scope or handled as a separate flow.

---

## Decisions Needed

- Confirm whether the target is a scratch org, sandbox, or direct production deployment.
- Decide on namespace usage (currently empty in `sfdx-project.json`). If this solution is intended for packaging and distribution, a namespace is required.
- Confirm the Experience Cloud site name and base URL so the `Submission_Link__c` formula can be finalised.
