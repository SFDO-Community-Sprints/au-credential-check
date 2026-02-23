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
- Confirm whether `Unique_Token__c` needs to be an Encrypted field (rather than plain Text) to prevent it appearing in debug logs or SOQL query results.

### Security
- Add a "Regenerate Token" action on the Credential record page. Currently, if a submission link is compromised, there is no way to invalidate it other than changing the Status (which resets the time window but not the token). A button that triggers a flow to regenerate `Unique_Token__c` would allow full revocation.
- Review Experience Cloud security checklist (CSP headers, clickjacking protection) before go-live.
- Confirm how files uploaded by the guest user are associated in Salesforce's file ownership model and whether this affects access controls.

### Flow
- Confirm the mechanism for generating the GUID in the Token Generation Flow. Salesforce does not have a native GUID formula function. An Apex invocable action may be required. Research options: `UUID.randomUUID()` in Apex, or a flow formula workaround.
- Rate limiting on the intake form is not implemented. If abuse is a concern, consider adding an Apex invocable action to detect and reject repeated invalid token attempts from the same IP.

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
