# Decision: Use GUID Token for Submission Link Access Control

## Context

Volunteers receive a unique URL to access the submission form. That URL must identify which Credential record they are submitting against, without revealing the Salesforce record ID and without requiring authentication.

We need a mechanism that:
- Uniquely identifies a specific Credential record
- Cannot be guessed or enumerated by an attacker
- Can be embedded in a URL sent via email or SMS
- Requires no volunteer account or login

## Options Considered

**Option A: Use the Salesforce Record ID directly**
Embed the `Credential__c` record ID in the URL (e.g. `?id=a0BXXXXXXX`). Simple to implement - no extra field needed. However, Salesforce record IDs follow a predictable format and incrementally increment within an object. An attacker who discovers one valid ID could enumerate adjacent IDs and access other volunteers' submission forms. This is an IDOR (Insecure Direct Object Reference) vulnerability.

**Option B: Short code or PIN**
Generate a short (e.g. 6-8 character) alphanumeric code and send it separately from the URL. The user enters the code on the site to gain access. More friction for the user, requires additional UI elements, and a short code is statistically brute-forceable if the endpoint does not implement rate limiting. Experience Cloud does not natively support rate limiting on flow inputs.

**Option C: GUID (Globally Unique Identifier)**
Generate a cryptographically random GUID (e.g. `a3f7b9c1-2d4e-4f8a-b0c2-1e3f5a7b9d0e`) and store it in a hidden field on the Credential record. Embed only the GUID in the submission URL. The GUID has 2^122 possible values - brute-force enumeration is computationally infeasible.

## Decision

Option C - GUID token stored in `Unique_Token__c` and embedded in `Submission_Link__c`.

This is the industry-standard pattern for time-limited, unauthenticated access links (used by password reset flows, document signing, survey tools, etc.). It eliminates IDOR risk, requires no user account, and works over email and SMS.

## Consequences

- A Record-Triggered Flow (After Insert) must generate the GUID on Credential creation. Salesforce does not have a native GUID formula function; the flow uses `{!$GlobalConstant.EmptyString}` combined with a formula or invocable action to generate the value. Confirm the specific generation method during Phase 2 - an Apex invocable action may be required if a pure-flow GUID generator is not available.
- The GUID is the access credential. If a volunteer forwards their link to another person, that person can submit on their behalf. This is an accepted risk given the low-sensitivity nature of the operation (the volunteer is submitting their own document). The time-bound window (Link Expiry Days) limits the exposure period.
- There is currently no mechanism to regenerate the GUID if a link is compromised. A "Regenerate Token" admin action would mitigate this. Added to `docs/todo.md`.
- `Unique_Token__c` must never be displayed in the UI, logged, or included in any list view or report visible to volunteers.
