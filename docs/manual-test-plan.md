# Manual Test Plan

Test scenarios for the Credential Intake System. Run these before any production deployment and after significant changes to flows, objects, or site configuration.

---

## Group 1: Admin - Credential Type Setup

### 1.1 Create a Credential Type

**Preconditions:** Admin is logged into Salesforce with access to the Credentials app.

**Steps:**
1. Navigate to the Credential Types tab.
2. Click New.
3. Enter a Type label: "Test Police Check".
4. Set Days Before Expiry: 30.
5. Set Link Expiry Days: 7.
6. Leave Does Not Expire unchecked.
7. Save.

**Expected result:** Record is created. Auto-Number Name is assigned (e.g. CT-0001). All fields are saved correctly.

**Pass / Fail:** ___

---

### 1.2 Create a Credential Type that Does Not Expire

**Steps:**
1. Repeat steps in 1.1 but tick Does Not Expire.

**Expected result:** Record saved with Does_Not_Expire__c = TRUE.

**Pass / Fail:** ___

---

## Group 2: Admin - Credential Lifecycle

### 2.1 Create a Credential and Request Submission

**Preconditions:** A Contact record exists. A Credential Type exists (CT-0001).

**Steps:**
1. Open the Contact record.
2. In the Credentials related list, click New.
3. Select Credential Type: CT-0001.
4. Save. Confirm the Status is Draft and Requested Date is empty.
5. Change Status to Requested. Save.
6. Open the Credential record.
7. Navigate to the Credential Requests related list. Confirm a new Credential Request record has been created.
8. Open the Credential Request record.

**Expected result:** Credential Status is Requested. Requested Date on the Credential is stamped with the current date and time. A Credential Request record exists with Status = Awaiting Submission. Submission Link is visible in the highlights panel on the Credential Request record and contains a GUID token.

**Pass / Fail:** ___

---

### 2.2 Submission Link is Copyable

**Preconditions:** A Credential record with Status = Requested exists with a linked Credential Request.

**Steps:**
1. Open the Credential record.
2. Navigate to the Credential Requests related list and open the Credential Request.
3. Find the Submission Link in the highlights panel at the top of the Credential Request record.
4. Copy the link.
5. Paste into a text editor and inspect the URL.

**Expected result:** URL is in the format `[site-base-url]/s/submit?id=[GUID]`. The GUID is a long random string, not a Salesforce record ID.

**Pass / Fail:** ___

---

### 2.3 Activate Without Sighting is Blocked

**Preconditions:** A Credential record with Status = Under Review and Sighted = FALSE.

**Steps:**
1. Open the Credential record.
2. Change Status to Active. Save.

**Expected result:** Salesforce shows a validation error. Status is not updated. Message indicates Sighted must be checked.

**Pass / Fail:** ___

---

### 2.4 Approval Activates Credential Automatically

**Preconditions:** A Credential record with Status = Under Review and a linked Credential Request with Status = Pending Review containing Issued By and Expiry Date values.

**Steps:**
1. Open the Credential Request record.
2. Change Status to Approved. Save.

**Expected result:** The `Credential_Request_Approval` flow fires. On the linked Credential record: Status = Active, Sighted = TRUE, Issued_By__c and Expiry_Date__c are populated with the values from the Credential Request. No manual sighting or status change required.

**Pass / Fail:** ___

---

## Group 3: Volunteer - Happy Path Submission

### 3.1 Valid Link Loads the Form

**Preconditions:** A Credential record with Status = Requested and a linked Credential Request with Status = Awaiting Submission. The request was created within the last Link_Expiry_Days days.

**Steps:**
1. Open the Submission Link from the Credential Request highlights panel in an incognito browser window (to simulate no Salesforce session).
2. Observe the page.

**Expected result:** The intake form loads. The Credential Type label is displayed (e.g. "Police Check"). Fields for Issued By and Expiry Date are present. A file upload control is present. No Salesforce login prompt appears.

**Pass / Fail:** ___

---

### 3.2 Submit a Valid Form

**Preconditions:** The intake form is loaded (scenario 3.1).

**Steps:**
1. Enter Issued By: "NSW Police Force".
2. Enter Expiry Date: a future date.
3. Upload a test PDF file.
4. Click Submit.

**Expected result:** A success confirmation screen is displayed. Back in Salesforce:
- The **Credential** record Status is now Under Review. `Issued_By__c` and `Expiry_Date__c` on the Credential remain blank (they are not written until the request is approved).
- The **Credential Request** record Status is now Pending Review. `Issued_By__c` = "NSW Police Force", `Expiry_Date__c` = the entered date.
- The uploaded file appears in the **Files related list on the Credential Request** (not on the Credential record).

**Pass / Fail:** ___

---

### 3.3 Does Not Expire Hides Expiry Date Field

**Preconditions:** A Credential record linked to a Credential Type where Does_Not_Expire__c = TRUE.

**Steps:**
1. Open the Submission Link in an incognito browser.

**Expected result:** The Expiry Date field is not shown on the form.

**Pass / Fail:** ___

---

## Group 4: Volunteer - Error and Edge Cases

### 4.1 Invalid Token Shows Error Screen

**Steps:**
1. Manually modify the submission URL to use a fake token (e.g. replace the id value with random characters).
2. Open the modified URL in a browser.

**Expected result:** An "Invalid Link" error screen is displayed. No Credential data is shown.

**Pass / Fail:** ___

---

### 4.2 Expired Link Shows Error Screen

**Preconditions:** A Credential Request where the Credential Type has `Link_Expiry_Days__c` set to a value smaller than the number of days since the request was created (i.e. the link window has closed). Setting `Link_Expiry_Days__c = 0` on the Credential Type is the easiest way to simulate this in a test environment.

**Steps:**
1. Open the Submission Link for the expired request in an incognito browser.

**Expected result:** A "Link Expired" error screen is displayed. No form is shown.

**Pass / Fail:** ___

---

### 4.3 Already Submitted Link Shows Error Screen

**Preconditions:** A Credential Request with Status = Pending Review (already submitted).

**Steps:**
1. Open the original Submission Link for this request in an incognito browser.

**Expected result:** An "Already Submitted" error screen is displayed. No form is shown.

**Pass / Fail:** ___

---

### 4.4 Reloading After Submission Shows Already Submitted

**Preconditions:** Form submitted successfully (scenario 3.2).

**Steps:**
1. Reload the same submission URL in the browser.

**Expected result:** The "Already Submitted" screen is shown. The form does not reload.

**Pass / Fail:** ___

---

## Group 5: Admin - Approval and Rejection

### 5.1 Approve a Submission

**Preconditions:** A Credential Request with Status = Pending Review, Issued_By__c and Expiry_Date__c populated, and an uploaded file attached.

**Steps:**
1. Open the Credential Request record.
2. Review the Issued By and Expiry Date values.
3. Open the Files related list and verify the uploaded document is present.
4. Change Status to Approved. Save.

**Expected result:** The `Credential_Request_Approval` flow fires. The linked Credential record now shows: Status = Active, Sighted = TRUE, Issued_By__c and Expiry_Date__c match the request values.

**Pass / Fail:** ___

---

### 5.2 Reject a Submission

**Preconditions:** A Credential Request with Status = Pending Review.

**Steps:**
1. Open the Credential Request record.
2. Change Status to Rejected. Save.

**Expected result:** The Credential Request Status is Rejected. No changes are made to the linked Credential record. The Credential Request is retained as an audit record.

**Pass / Fail:** ___

---

### 5.3 Reissue a Link After Rejection

**Preconditions:** A Credential record with Status = Under Review (from a rejected submission).

**Steps:**
1. Open the Credential record.
2. Change Status to Draft. Save.
3. Change Status back to Requested. Save.
4. Navigate to the Credential Requests related list.

**Expected result:** A new Credential Request record is created with Status = Awaiting Submission and a new unique Submission Link. The previously rejected request still exists in the related list. The old Submission Link no longer works (shows Already Submitted or Invalid Link).

**Pass / Fail:** ___

---

## Group 6: Automation (Not Yet Built)

The following scenarios apply to features that have not yet been implemented. Mark as N/A until the features are built.

### 6.1 Nightly Expiry Flow - Mark Expired

**Status: NOT YET BUILT.** See `docs/todo.md`.

**Preconditions:** A Credential record with Status = Active and Expiry_Date__c set to yesterday.

**Steps:**
1. Manually trigger or simulate the Scheduled Flow (run it from Setup > Flows in a test context).

**Expected result:** The Credential Status changes to Expired.

**Pass / Fail:** N/A

---

### 6.2 Submission Confirmation Email Sent

**Status: NOT YET BUILT.** See `docs/todo.md`.

**Preconditions:** A Credential record linked to a Contact with a valid email address. Form submitted successfully (scenario 3.2).

**Steps:**
1. Check the email inbox of the Contact.

**Expected result:** A submission confirmation email is received. The email references the credential type and submission.

**Pass / Fail:** N/A

---
