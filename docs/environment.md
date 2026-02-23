# Environment and Setup

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) v2+
- VS Code with [Salesforce Extensions Pack](https://developer.salesforce.com/tools/vscode/)
- Access to the target Salesforce org (sandbox or production) with System Administrator profile, or ability to create scratch orgs

---

## Local Development Setup

### 1. Authenticate to the Target Org

```bash
sf org login web --alias credential-check-au
```

### 2. Deploy Source to the Org

```bash
sf project deploy start
```

### 3. Open the Org

```bash
sf org open
```

### Scratch Org Setup

If using a scratch org, create one from the project definition:

```bash
sf org create scratch --definition-file config/project-scratch-def.json --alias credential-check-scratch --duration-days 30
sf project deploy start --target-org credential-check-scratch
sf org open --target-org credential-check-scratch
```

---

## Required Salesforce Features

The following must be enabled in the target org before deploying:

| Feature | Why it is needed |
|---|---|
| Experience Cloud | Hosts the public volunteer submission form |
| Salesforce Files (ContentDocument) | Stores uploaded credential documents |
| Flow (Screen Flows, Scheduled Flows, Record-Triggered Flows) | Core automation engine |
| Field History Tracking | Audit trail on `Sighted__c` |

Confirm these are enabled in Setup before beginning Phase 2.

---

## Configuration Required After Deployment

The following cannot be captured in source metadata and must be configured manually in each org:

1. **Experience Cloud site creation** - create the site in Setup > Digital Experiences > All Sites. Note the site URL.
2. **Update `Submission_Link__c` formula** - replace the site URL placeholder with the actual site base URL.
3. **Guest User Profile configuration** - enable "Run Flows" permission, disable all object CRUD permissions.
4. **Deploy the Intake Flow to the site page** - add the flow component to the public site page in Experience Builder.
5. **Scheduled Flow schedule** - set the nightly run schedule in Setup > Flows after deployment.

---

## Environment Variables

This project does not use environment variables or external secrets. All configuration is managed within the Salesforce org.

The only org-specific value that requires manual configuration is the Experience Cloud site base URL, which is used in the `Submission_Link__c` formula field. This is not a secret - it is the public-facing URL of the site.

---

## Scratch Org Configuration

See `config/project-scratch-def.json` for the scratch org shape. Update this file to add Experience Cloud and any other required features when confirmed for the target org.
