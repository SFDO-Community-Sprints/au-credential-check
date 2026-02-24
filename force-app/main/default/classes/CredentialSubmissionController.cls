/**
 * Apex controller for the credentialSubmissionForm LWC.
 *
 * Runs without sharing because the guest user on the Experience Cloud site has no
 * object permissions on Credential__c, Credential_Request__c, or ContentVersion.
 * This class acts as the privileged data proxy - the same security model as the
 * Credential_Intake_Form screen flow which runs in System Context Without Sharing.
 *
 * Security controls applied at the application layer instead:
 *   - All read/write operations are gated by the Unique_Token__c value from the URL.
 *   - submitCredential re-validates the token before any DML to prevent replay if
 *     the link expires between page load and form submit.
 *   - uploadFile validates that requestId is a real Credential_Request__c before
 *     accepting file data.
 *   - No Salesforce record IDs are exposed to the browser except the
 *     Credential_Request__c Id returned after a successful submit (required for
 *     file attachment).
 *
 * Does not own: Experience Cloud site configuration, Guest User profile
 * permissions, or the approval flow that fires when Credential_Request__c
 * Status__c changes to Approved.
 */
public without sharing class CredentialSubmissionController {

    // Status codes returned to the LWC state machine. These string values must
    // match the STATE_* constants defined in credentialSubmissionForm.js.
    private static final String STATUS_OK                = 'OK';
    private static final String STATUS_INVALID_LINK      = 'INVALID_LINK';
    private static final String STATUS_ALREADY_SUBMITTED = 'ALREADY_SUBMITTED';
    private static final String STATUS_LINK_EXPIRED      = 'LINK_EXPIRED';

    // Credential__c.Status__c picklist values relevant to submission gating.
    // 'Requested' is the only status that permits a new submission.
    private static final String CREDENTIAL_STATUS_REQUESTED    = 'Requested';
    private static final String CREDENTIAL_STATUS_UNDER_REVIEW = 'Under Review';

    // Credential_Request__c.Status__c initial value written on creation.
    private static final String REQUEST_STATUS_PENDING_REVIEW = 'Pending Review';

    /**
     * Wrapper returned from getCredentialByToken to the LWC.
     *
     * Using a typed inner class rather than a Map so the LWC receives a
     * stable, predictable shape and avoids property-existence checks on the
     * JavaScript side. All fields are null unless status = OK.
     */
    public class CredentialInfo {

        /**
         * Result code driving the LWC state machine.
         * One of: OK | INVALID_LINK | ALREADY_SUBMITTED | LINK_EXPIRED.
         */
        @AuraEnabled public String status;

        /** Salesforce Id of the matched Credential__c. Null unless status = OK. */
        @AuraEnabled public String credentialId;

        /**
         * Display label for the credential type (Credential_Type__r.Name).
         * Null unless status = OK.
         */
        @AuraEnabled public String credentialType;

        /**
         * Whether this credential type never expires.
         * When true the LWC hides the Expiry Date input and passes null on submit.
         * Null unless status = OK.
         */
        @AuraEnabled public Boolean doesNotExpire;
    }

    /**
     * Looks up a Credential__c by its access token and returns the validation
     * result so the LWC can enter the appropriate state on load.
     *
     * Called imperatively (not via @wire) from the LWC because guest users on
     * LWR Experience Cloud sites cannot use @wire callouts reliably.
     *
     * @param token  The GUID from the ?id= URL parameter. Used as a SOQL bind
     *               variable - never concatenated into the query string.
     * @return       CredentialInfo with status = OK and populated fields when the
     *               link is valid and unused; otherwise status = INVALID_LINK,
     *               ALREADY_SUBMITTED, or LINK_EXPIRED with all data fields null.
     * @example
     *   CredentialInfo info = CredentialSubmissionController.getCredentialByToken('abc-def');
     *   if (info.status == 'OK') { System.debug(info.credentialType); }
     */
    @AuraEnabled
    public static CredentialInfo getCredentialByToken(String token) {
        List<Credential__c> records = [
            SELECT  Id,
                    Status__c,
                    Requested_Date__c,
                    Credential_Type__c,
                    Credential_Type__r.Name,
                    Credential_Type__r.Link_Expiry_Days__c,
                    Credential_Type__r.Does_Not_Expire__c
            FROM    Credential__c
            WHERE   Unique_Token__c = :token
            LIMIT   1
        ];

        if (records.isEmpty()) {
            return buildErrorInfo(STATUS_INVALID_LINK);
        }

        Credential__c credential = records[0];

        if (credential.Status__c != CREDENTIAL_STATUS_REQUESTED) {
            return buildErrorInfo(STATUS_ALREADY_SUBMITTED);
        }

        if (isLinkExpired(credential)) {
            return buildErrorInfo(STATUS_LINK_EXPIRED);
        }

        CredentialInfo info    = new CredentialInfo();
        info.status            = STATUS_OK;
        info.credentialId      = credential.Id;
        info.credentialType    = credential.Credential_Type__r.Name;
        info.doesNotExpire     = credential.Credential_Type__r.Does_Not_Expire__c;
        return info;
    }

    /**
     * Creates a Credential_Request__c staging record and updates the linked
     * Credential__c status to Under Review.
     *
     * Re-validates the token before any DML so that a submission attempt on an
     * expired or already-used link is rejected even if the page loaded earlier
     * when the link was still valid.
     *
     * @param token       The GUID from the URL - identifies the Credential__c.
     * @param issuedBy    Free-text name of the issuing authority or organisation.
     * @param expiryDate  Date the credential expires. Null for non-expiring types.
     * @return            The Id of the new Credential_Request__c, which the LWC
     *                    passes to uploadFile for each selected file.
     * @throws AuraHandledException  If the token is no longer valid or DML fails.
     *                               The message is safe to surface in the UI.
     * @example
     *   String requestId = CredentialSubmissionController.submitCredential(
     *       'abc-def', 'Queensland Police', Date.newInstance(2027, 1, 1));
     */
    @AuraEnabled
    public static String submitCredential(String token, String issuedBy, Date expiryDate) {
        List<Credential__c> records = [
            SELECT  Id,
                    Status__c,
                    Requested_Date__c,
                    Credential_Type__r.Link_Expiry_Days__c,
                    Credential_Type__r.Does_Not_Expire__c
            FROM    Credential__c
            WHERE   Unique_Token__c = :token
            LIMIT   1
        ];

        if (records.isEmpty()) {
            throw new AuraHandledException(
                'This link is not valid. Please contact your administrator.'
            );
        }

        Credential__c credential = records[0];

        if (credential.Status__c != CREDENTIAL_STATUS_REQUESTED) {
            throw new AuraHandledException('This form has already been submitted.');
        }

        if (isLinkExpired(credential)) {
            throw new AuraHandledException(
                'This link has expired. Please contact your administrator to request a new link.'
            );
        }

        try {
            Credential_Request__c request = new Credential_Request__c(
                Credential__c  = credential.Id,
                Status__c      = REQUEST_STATUS_PENDING_REVIEW,
                Issued_By__c   = issuedBy,
                Expiry_Date__c = expiryDate
            );
            insert request;

            credential.Status__c = CREDENTIAL_STATUS_UNDER_REVIEW;
            update credential;

            return request.Id;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            // Log full detail internally; return a generic message to avoid
            // exposing record IDs or internal structure in the error response.
            System.debug(LoggingLevel.ERROR, 'submitCredential failed: ' + e.getMessage());
            throw new AuraHandledException(
                'Submission failed. Please try again or contact your administrator.'
            );
        }
    }

    /**
     * Creates a ContentVersion record for a single uploaded file and links it
     * to the specified Credential_Request__c.
     *
     * Salesforce automatically creates a ContentDocumentLink when
     * FirstPublishLocationId is set on a new ContentVersion, so no separate
     * ContentDocumentLink insert is needed.
     *
     * The LWC calls this once per file, sequentially, after submitCredential
     * succeeds. Sequential rather than parallel to avoid concurrent heap
     * pressure from multiple base64 payloads simultaneously.
     *
     * @param requestId   Salesforce Id of the Credential_Request__c to attach
     *                    the file to. Validated before use.
     * @param fileName    Original filename including extension, used as the
     *                    ContentVersion Title and PathOnClient.
     * @param base64Data  Raw base64-encoded file content with the data URI
     *                    prefix already stripped by the LWC.
     * @throws AuraHandledException  If requestId is invalid or the insert fails.
     * @example
     *   CredentialSubmissionController.uploadFile(requestId, 'police-check.pdf', base64Str);
     */
    @AuraEnabled
    public static void uploadFile(String requestId, String fileName, String base64Data) {
        // Verify requestId refers to a real Credential_Request__c before accepting
        // the file. Without this check a caller could supply any record Id and
        // attach files to arbitrary objects via this endpoint.
        List<Credential_Request__c> requests = [
            SELECT Id
            FROM   Credential_Request__c
            WHERE  Id = :requestId
            LIMIT  1
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'Invalid request reference. Please re-submit the form.'
            );
        }

        try {
            ContentVersion cv = new ContentVersion(
                Title                  = fileName,
                PathOnClient           = fileName,
                VersionData            = EncodingUtil.base64Decode(base64Data),
                FirstPublishLocationId = requestId
            );
            insert cv;

        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'uploadFile failed for "' + fileName + '": ' + e.getMessage()
            );
            throw new AuraHandledException(
                'File upload failed for "' + fileName + '". Please try again.'
            );
        }
    }

    /**
     * Returns a CredentialInfo populated with only an error status code.
     * Used for the three rejection paths where no credential data should be
     * returned to the caller.
     *
     * @param errorStatus  One of: INVALID_LINK | ALREADY_SUBMITTED | LINK_EXPIRED.
     * @return             CredentialInfo with the given status and null data fields.
     */
    private static CredentialInfo buildErrorInfo(String errorStatus) {
        CredentialInfo info = new CredentialInfo();
        info.status = errorStatus;
        return info;
    }

    /**
     * Determines whether the submission link for a credential has passed its
     * expiry date.
     *
     * Expiry is calculated as: Requested_Date__c.date() + Link_Expiry_Days__c days.
     * A null Requested_Date__c is treated as expired because the link timer was
     * never started, meaning the link should not have been distributed yet.
     * The cast to Integer is safe because Link_Expiry_Days__c is a required Number
     * field on the object.
     *
     * @param credential  Credential__c with Requested_Date__c and
     *                    Credential_Type__r.Link_Expiry_Days__c populated.
     * @return            True if the link has expired or Requested_Date__c is null.
     */
    private static Boolean isLinkExpired(Credential__c credential) {
        if (credential.Requested_Date__c == null) {
            return true;
        }
        Integer expiryDays = (Integer) credential.Credential_Type__r.Link_Expiry_Days__c;
        Date    expiryDate = credential.Requested_Date__c.date().addDays(expiryDays);
        return Date.today() > expiryDate;
    }
}