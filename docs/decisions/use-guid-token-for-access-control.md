# Decision: Use GUID Token for Submission Link Access Control

## Context

Volunteers receive a unique URL to access the submission form. That URL must identify which submission request they are responding to, without revealing the Salesforce record ID and without requiring authentication.

We need a mechanism that:
- Uniquely identifies a specific `Credential_Request__c` record (one per submission window)
- Cannot be guessed or enumerated by an attacker
- Can be embedded in a URL sent via email or SMS
- Requires no volunteer account or login

## Options Considered

**Option A: Use the Salesforce Record ID directly**
Embed the `Credential__c` record ID in the URL (e.g. `?id=a0BXXXXXXX`). Simple to implement - no extra field needed. However, Salesforce record IDs follow a predictable format and increment within an object. An attacker who discovers one valid ID could enumerate adjacent IDs and access other volunteers' submission forms. This is an IDOR (Insecure Direct Object Reference) vulnerability.

**Option B: Short code or PIN**
Generate a short (e.g. 6-8 character) alphanumeric code and send it separately from the URL. The user enters the code on the site to gain access. More friction for the user, requires additional UI elements, and a short code is statistically brute-forceable if the endpoint does not implement rate limiting. Experience Cloud does not natively support rate limiting on flow inputs.

**Option C: GUID (Globally Unique Identifier)**
Generate a cryptographically random GUID (e.g. `a3f7b9c1-2d4e-4f8a-b0c2-1e3f5a7b9d0e`) and store it in a hidden field on the request record. Embed only the GUID in the submission URL. The GUID has 2^122 possible values - brute-force enumeration is computationally infeasible.

## Decision

Option C - GUID token stored in `Credential_Request__c.Unique_Token__c` and embedded in `Credential_Request__c.Submission_Link__c`.

This is the industry-standard pattern for time-limited, unauthenticated access links (used by password reset flows, document signing, survey tools, etc.). It eliminates IDOR risk, requires no user account, and works over email and SMS.

Token ownership was initially on `Credential__c` (one token per credential for its entire lifetime). This was restructured in the Phase 4 token restructure to place the token on `Credential_Request__c` (one token per submission window). This design is strictly stronger: each time an admin reissues a link, a new request record is created with a new token, so old links are automatically invalidated without any additional logic.

## Implementation

The `Credential_Request_Creation` record-triggered flow (After Update on `Credential__c`, fires when Status moves to Requested) calls the `GenerateUUID` Apex invocable action. That action uses `Crypto.generateAesKey(128)` to produce 16 bytes of cryptographic randomness, converts to hex, and formats as a standard UUID string (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). The UUID is stored in `Unique_Token__c` (Text 36, Unique) on the newly created `Credential_Request__c` record.

`Crypto.generateAesKey(128)` was chosen over alternatives (e.g. `Math.random()`, `UUID.randomUUID()`) because it is the established Salesforce-approved cryptographic random source. See the `GenerateUUID` class comment for detail.

## Consequences

- The GUID is the access credential. If a volunteer forwards their link to another person, that person can submit on their behalf. This is an accepted risk given the low-sensitivity nature of the operation (the volunteer is submitting their own document). The time-bound window (`Link_Expiry_Days__c`) limits the exposure period.
- Because the token is on `Credential_Request__c` (not `Credential__c`), an admin can invalidate a live link immediately by setting the Credential Request Status to Rejected. The existing ALREADY_SUBMITTED gate handles this: any status other than Awaiting Submission returns an error to the volunteer.
- There is currently no "Regenerate Token" button to refresh a link without changing Status. A dedicated admin action would allow revocation without the Status change side effects. Added to `docs/todo.md`.
- `Unique_Token__c` must never be displayed in the UI (other than through the Submission Link formula), logged, or included in any list view or report visible to volunteers.
