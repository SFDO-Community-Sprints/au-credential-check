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
4. Save. Note the Status is "Draft" and Requested Date is empty.
5. Change Status to "Requested". Save.
6. Open the Credential record.

**Expected result:** Status is "Requested". Requested Date is automatically stamped with the current date and time. Submission Link is visible in the Highlights Panel.

**Pass / Fail:** ___

---

### 2.2 Submission Link is Copyable

**Preconditions:** A Credential record with Status = "Requested" exists.

**Steps:**
1. Open the Credential record.
2. Find the Submission Link in the Highlights Panel.
3. Copy the link.
4. Paste into a text editor and inspect the URL.

**Expected result:** URL is in the format `[site-base-url]/s/submit?id=[GUID]`. The GUID is a long random string, not a Salesforce record ID.

**Pass / Fail:** ___

---

### 2.3 Activate Without Sighting is Blocked

**Preconditions:** A Credential record with Status = "Under Review" and Sighted = FALSE.

**Steps:**
1. Open the Credential record.
2. Change Status to "Active". Save.

**Expected result:** Salesforce shows a validation error. Status is not updated. Message indicates Sighted must be checked.

**Pass / Fail:** ___

---

### 2.4 Activate After Sighting Succeeds

**Steps:**
1. Tick the Sighted checkbox on the Credential record. Save.
2. Change Status to "Active". Save.

**Expected result:** Status is saved as "Active". No validation error.

**Pass / Fail:** ___

---

## Group 3: Volunteer - Happy Path Submission

### 3.1 Valid Link Loads the Form

**Preconditions:** A Credential record with Status = "Requested" and a valid Submission Link. The link has not expired (Requested Date is within the last Link_Expiry_Days days).

**Steps:**
1. Open the Submission Link in a browser (use an incognito window to simulate no Salesforce session).
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

**Expected result:** A success confirmation screen is displayed. Back in Salesforce, the Credential record Status is now "Under Review". Issued_By__c and Expiry_Date__c are populated. The uploaded file appears in the Files related list on the Credential record.

**Pass / Fail:** ___

---

### 3.3 Does Not Expire hides Expiry Date Field

**Preconditions:** A Credential record linked to a Credential Type where Does_Not_Expire__c = TRUE.

**Steps:**
1. Open the Submission Link in an incognito browser.

**Expected result:** The Expiry Date field is not shown on the form.

**Pass / Fail:** ___

---

## Group 4: Volunteer - Error and Edge Cases

### 4.1 Invalid Token Shows Error Screen

**Steps:**
1. Manually modify the submission URL to use a fake token (e.g. append random characters to the id parameter).
2. Open the modified URL in a browser.

**Expected result:** An "Invalid Link" error screen is displayed. No Credential data is shown.

**Pass / Fail:** ___

---

### 4.2 Expired Link Shows Error Screen

**Preconditions:** A Credential record with Status = "Requested" where Requested_Date__c is older than Link_Expiry_Days on the Credential Type.

**Steps:**
1. Open the Submission Link for this record in an incognito browser.

**Expected result:** A "Link Expired" error screen is displayed. No form is shown.

**Pass / Fail:** ___

---

### 4.3 Already Submitted Link Shows Error Screen

**Preconditions:** A Credential record with Status = "Under Review" (already submitted).

**Steps:**
1. Open the original Submission Link for this record in an incognito browser.

**Expected result:** An "Already Submitted" error screen is displayed. No form is shown.

**Pass / Fail:** ___

---

### 4.4 File Type Restriction - Rejected File

**Preconditions:** The intake form is loaded (scenario 3.1).

**Steps:**
1. Attempt to upload a .docx or .xlsx file via the file upload control.

**Expected result:** The upload is rejected. An error or restriction message is shown. Only .pdf, .jpg, and .png are accepted.

**Pass / Fail:** ___

---

## Group 5: Automation

### 5.1 Nightly Expiry Flow - Mark Expired

**Preconditions:** A Credential record with Status = "Active" and Expiry_Date__c set to yesterday.

**Steps:**
1. Manually trigger or simulate the Scheduled Flow (run it from Setup > Flows in a test context).

**Expected result:** The Credential Status changes to "Expired".

**Pass / Fail:** ___

---

### 5.2 Submission Confirmation Email Sent

**Preconditions:** A Credential record linked to a Contact with a valid email address. Form submitted successfully (scenario 3.2).

**Steps:**
1. Check the email inbox of the Contact.

**Expected result:** A submission confirmation email is received. The email references the credential type and submission.

**Pass / Fail:** ___
