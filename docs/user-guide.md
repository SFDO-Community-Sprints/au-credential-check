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
5. Change the Status to **Requested** and save. The system automatically records the date and time of this change.
6. On the Credential record, find the **Submission Link** in the highlights panel at the top.
7. Click the copy icon next to the link and paste it into an email, SMS, or however you communicate with the volunteer.

The link will remain active for the number of days set on the Credential Type. After that window closes, the link no longer works and you will need to reset the status and send a new link if required.

### Reviewing a Submission

When a volunteer submits their document, the Credential status automatically changes to **Under Review**. You can monitor this via a list view or report.

**To review and activate a submission:**

1. Open the Credential record. You will see the file attached in the Files related list.
2. Open and review the document.
3. If the document is valid, tick the **Sighted** checkbox to confirm you have physically or digitally reviewed the original.
4. Update the **Expiry Date** if not already set by the volunteer.
5. Change the Status to **Active**.

Note: the system will not allow you to set the status to Active unless the Sighted checkbox is ticked. This is a deliberate safeguard.

### Common Issues

| Situation | What to do |
|---|---|
| Volunteer says the link doesn't work | Check if the link has expired (compare today's date against Requested Date + Link Expiry Days on the Credential Type). Reset status to Draft then back to Requested to regenerate the expiry window, then resend the link. |
| Volunteer submitted the wrong file | The submission cannot be recalled once submitted. Change status back to Requested and send a new link, or manually replace the file in Salesforce. |
| Status is stuck on Under Review | Someone needs to review and sighted the document. Assign the record to the appropriate reviewer. |
| Cannot set status to Active | Confirm the Sighted checkbox is ticked. The system blocks activation without it. |

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
| "This link is no longer valid." | The link has expired or has already been used. Contact your coordinator to request a new link. |
| "This submission has already been received." | Your document was already submitted successfully. Contact your coordinator if you need to resubmit. |
| "Invalid link." | The URL may be incomplete or corrupted. Try copying and pasting the full link from your message into a browser. |

### Who to Contact

If you have any trouble with the form, contact the coordinator who sent you the link. They can reissue the link or assist with the submission.
