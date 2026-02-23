# Decision: Use Screen Flow in System Mode for the Public Form

## Context

The volunteer form is accessed by unauthenticated users via an Experience Cloud site. These users have no Salesforce account. We need a mechanism that allows them to read a specific Credential record (to display the credential type label), write to that record (to save their submission), and attach a file - all without having direct access to any Salesforce objects.

The core challenge: how do you let an anonymous user interact with Salesforce data without granting broad access?

## Options Considered

**Option A: Grant Guest User Profile object permissions**
Give the Guest User read/write access to `Credential__c` directly via the Guest Profile. Simple to configure, but gives the anonymous internet access to Salesforce objects. Even with field-level security, this creates a large attack surface and requires careful OWD and sharing rule management to prevent data leakage between volunteers.

**Option B: Apex REST endpoint**
Build a custom Apex REST controller that accepts the token and handles reads and writes. Gives precise control but requires custom code, adds complexity, and means Apex must be maintained long-term. The SFDO community sprint context means declarative solutions are strongly preferred for maintainability.

**Option C: Screen Flow in System Context Without Sharing**
Build a Screen Flow that runs with elevated system permissions. The Guest User Profile has zero object access but has the "Run Flows" system permission. The flow performs all data access on behalf of the user. The token validation logic inside the flow ensures only the intended record is read or written.

## Decision

Option C - Screen Flow in System Context Without Sharing.

This is the standard Salesforce pattern for unauthenticated form collection. It gives precise control over what the anonymous user can do (only what the flow allows), requires no custom code, and is maintainable by Salesforce admins without developer involvement.

## Consequences

- The flow runs Without Sharing. This is intentional but must be documented clearly (done here and in `docs/security.md`). Without Sharing means the flow can access any record it has a reference to, regardless of sharing rules - which is exactly what we need for a guest user scenario.
- Any logic change to what the form does requires changing the flow, not code. This is a positive for admin maintainability.
- The flow must be the sole data access point for guest users. No other mechanism (e.g. Apex, direct API) should be enabled for the Guest Profile.
- Future enhancements that require more complex branching or external callouts may eventually outgrow what a Screen Flow can handle cleanly. At that point, an Apex controller becomes the right choice. Note this in `docs/todo.md` if complexity grows.
