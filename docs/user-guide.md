# User Guide

This guide covers two audiences: **admins** who manage credentials inside Salesforce, and **volunteers** who submit their documents through the public form.

---

## For Admins

### Overview

As an admin, you create and manage Credential records in Salesforce. When a volunteer needs to submit a document, you generate a unique link from their Credential record and send it to them. Once they submit, you review their document, mark it as sighted, and activate the credential.

### Prerequisites

- A Salesforce login with access to the Credentials app
- The Contact or Account record for the volunteer must already exist in Salesforce

### Setting Up Credential Types

Credential Types define the categories of documents your organisation requires. Each type controls:

- The label shown to the volunteer on the submission form
- How many days before expiry a renewal notification is triggered
- How many days the submission link remains valid after being sent

**To create a Credential Type:**

1. Navigate to the Credential Types tab.
2. Click **New**.
3. Enter the credential label (e.g. "Police Check", "Driver's Licence").
4. Set **Days Before Expiry** - how far in advance you want to be alerted about upcoming renewals.
5. Set **Link Expiry Days** - how long the volunteer's submission link remains active (e.g. 7 days).
6. Tick **Does Not Expire** if the credential has no expiry date (e.g. a one-time check).
7. Save.

Credential Types only need to be created once. Reuse the same type for all volunteers submitting that document category.

### Requesting a Credential Submission

1. Open the Contact or Account record for the volunteer.
2. Navigate to the **Credentials** related list and click **New**.
3. Select the relevant **Credential Type**.
4. The record is created with status **Draft**.
5. Change the Status to **Requested** and save.
6. The system automatically does two things at this point:
   - Records the date and time of the status change on the Credential.
   - Creates a new **Credential Request** record linked to the Credential. This request contains the unique submission link for this specific request.
7. Open the new Credential Request from the **Credential Requests** related list on the Credential record.
8. Find the **Submission Link** in the highlights panel at the top of the Credential Request record.
9. Copy the link and send it to the volunteer via email, SMS, or however you communicate with them.

Each time you set a Credential to Requested, a brand new Credential Request is created with a fresh unique link. Links from earlier requests stop working when a new one is issued.

The link remains active for the number of days set in **Link Expiry Days** on the Credential Type. After that window closes, the link no longer works.

### How Submission Links Work

Each submission link is tied to a specific Credential Request record - not the Credential itself. The link contains a unique token (a randomly generated code) that identifies that exact request. This means:

- If you send the same link to someone twice, it still points to the same request.
- If you set Status back to Requested again, a completely new Credential Request is created with a new link and a fresh expiry window. The previous link stops working.
- The token in the URL cannot be guessed or constructed - it is randomly generated each time.

**If a link has expired:** Set the Credential Status back to Draft, then back to Requested. This creates a new Credential Request with a new link. Copy the new Submission Link from the new request record and resend it to the volunteer.

**If a link was sent to the wrong person or may be compromised:** Set the Credential Request Status to Rejected. This invalidates the link immediately - anyone opening it will see an error. Then set the Credential Status to Requested again to issue a fresh link to the correct recipient.

### Reviewing a Submission

When a volunteer submits their document, the Credential status automatically changes to **Under Review**. You can monitor this via a list view or report.

**To review and activate a submission:**

1. Open the Credential record and navigate to the **Credential Requests** related list.
2. Open the Credential Request with Status **Pending Review**.
3. Review the **Issued By** and **Expiry Date** values the volunteer entered.
4. Open the attached file from the **Files** related list on the Credential Request and review the document.
5. If the document is valid, change the Credential Request **Status** to **Approved**.
6. The system automatically updates the linked Credential: it copies Issued By and Expiry Date from the request, ticks the Sighted checkbox, and sets the Credential Status to **Active**.

If the document is not acceptable, set the Credential Request Status to **Rejected** and follow up with the volunteer directly. The rejected request is retained as an audit record.

### Common Issues

| Situation | What to do |
|---|---|
| Volunteer says the link has expired | Set the Credential Status to Draft, then back to Requested. A new Credential Request is created with a new link and fresh expiry window. Copy the Submission Link from the new request and resend it. |
| Volunteer says the link is invalid or won't load | Check the URL was not truncated when sent. If the link looks complete, the request may have been rejected or the Credential status may have changed. Set Status to Requested again to issue a new request. |
| Volunteer submitted the wrong file | The submission cannot be recalled once submitted. Set the Credential Request Status to Rejected, then set the Credential Status to Requested to issue a new request with a new link. |
| Submission Link is missing from the Credential Request | The link is a formula field built from the token. If it is blank, the Unique Token field on the request is empty - this should not happen under normal operation. Check whether the Credential_Request_Creation flow is active in Setup. |
| Status is stuck on Under Review | Open the Credential Request in Pending Review status and approve or reject it from there. |

---

## For Volunteers

### Overview

You have received a link asking you to submit a credential document (for example, a Police Check or Driver's Licence). The form takes a few minutes to complete. You do not need a Salesforce account.

### What You Need

- The link sent to you by your organisation's coordinator
- A digital copy of your document saved as a PDF, JPG, or PNG file
- The name of the issuing authority and the expiry date on your document (if applicable)

### How to Submit

1. Click the link in the message you received from your coordinator.
2. The submission form will load in your browser.
3. Enter the name of the organisation or authority that issued your document (e.g. "NSW Police Force").
4. If your document has an expiry date, enter it in the Expiry Date field.
5. Click **Upload File** and select your document from your device.
6. Click **Submit**.
7. You will see a confirmation message when your submission is successful.

Your coordinator will review your submission and contact you if anything further is needed.

### Common Issues

| Message | What it means |
|---|---|
| "This submission link has expired." | The link was valid for a limited number of days and that window has now closed. Contact your coordinator and ask them to send you a new link. |
| "Already submitted." | Your document was already submitted successfully using this link. Contact your coordinator if you need to resubmit. |
| "Link not valid." | The URL may be incomplete or corrupted, or the link has been cancelled. Try copying and pasting the full link from your message directly into a browser address bar. If it still does not work, contact your coordinator. |

### Who to Contact

If you have any trouble with the form, contact the coordinator who sent you the link. They can reissue the link or assist with the submission.
