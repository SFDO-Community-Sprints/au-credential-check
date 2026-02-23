# Decision: Use Experience Cloud to Host the Public Form

## Context

The volunteer form must be accessible to people with no Salesforce account, via a plain URL. We need a hosting mechanism that:
- Serves a public web page without requiring a login
- Can embed a Salesforce Screen Flow
- Is within the Salesforce platform (to avoid external infrastructure)
- Supports a Guest User Profile for permission control

## Options Considered

**Option A: Salesforce Sites (classic)**
The legacy Salesforce Sites product allows hosting Visualforce pages publicly. However, Visualforce is a dated technology, does not natively support Lightning components or Screen Flows, and would require custom code. Not suitable for a declarative flow-based solution.

**Option B: External web form (e.g. Typeform, Google Forms, Jotform)**
Use a third-party form tool and write submitted data back to Salesforce via a webhook or Zapier integration. Simpler for the volunteer experience but introduces external dependencies, data leaves Salesforce before being written back (privacy concern), file uploads become complex, and the integration adds ongoing maintenance overhead. Not appropriate for a self-contained Salesforce solution.

**Option C: Experience Cloud (Lightning Experience Site)**
Salesforce's modern digital experience platform. Natively supports Lightning components and Screen Flows. Provides a Guest User Profile for permission management. Hosts on a Salesforce-managed subdomain. The standard choice for public-facing Salesforce forms.

## Decision

Option C - Experience Cloud (unauthenticated Lightning site).

It is the natural host for a Salesforce Screen Flow intended for unauthenticated users. No external services are needed, files stay within the Salesforce org, and the Guest User Profile integrates directly with the permission model used by the System Mode flow.

## Consequences

- An Experience Cloud licence is required. Confirm this is available in the target org before Phase 2.
- The site must be configured as unauthenticated (no login page). The Guest User Profile is the sole access context for external users.
- The site URL format will be something like `https://[org-domain].my.site.com/[site-name]/s/submit`. This base URL must be hardcoded into the `Submission_Link__c` formula field - update this when the site is provisioned.
- Experience Cloud has its own set of security and governance considerations (CSP headers, clickjacking protection, etc.). Review the Experience Cloud security checklist before go-live.
