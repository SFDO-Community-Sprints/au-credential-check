/**
 * Apex controller for the credentialSubmissionForm LWC.
 *
 * Runs without sharing because the guest user on the Experience Cloud site has no
 * object permissions on Credential__c, Credential_Request__c, or ContentVersion.
 * This class acts as the privileged data proxy - the same security model as the
 * Credential_Intake_Form screen flow which runs in System Context Without Sharing.
 *
 * Security controls applied at the application layer instead:
 *   - All read/write operations are gated by the Unique_Token__c value on
 *     Credential_Request__c. The token is embedded in the URL and treated as
 *     the single credential for this anonymous submission session.
 *   - submitCredential re-validates the token before any DML to prevent replay
 *     if the link expires between page load and form submit.
 *   - uploadFile validates that requestId is a real Credential_Request__c before
 *     accepting file data.
 *   - No Salesforce record IDs are exposed to the browser except the
 *     Credential_Request__c Id returned after a successful submit (required for
 *     file attachment).
 *
 * Token ownership model (post phase-4 restructure):
 *   Unique_Token__c lives on Credential_Request__c, not Credential__c.
 *   Each time a Credential__c transitions to Status = Requested, the
 *   Credential_Request_Creation flow creates a new Credential_Request__c with a
 *   fresh UUID token and Status = Awaiting Submission. This controller queries
 *   Credential_Request__c by token rather than Credential__c, so each link is
 *   tied to exactly one request record.
 *
 * Does not own: Experience Cloud site configuration, Guest User profile
 * permissions, or the Credential_Request_Approval flow that fires when
 * Credential_Request__c Status__c changes to Approved.
 */
public without sharing class CredentialSubmissionController {

    // Status codes returned to the LWC state machine. These string values must
    // match the STATE_* constants defined in credentialSubmissionForm.js.
    private static final String STATUS_OK                = 'OK';
    private static final String STATUS_INVALID_LINK      = 'INVALID_LINK';
    private static final String STATUS_ALREADY_SUBMITTED = 'ALREADY_SUBMITTED';
    private static final String STATUS_LINK_EXPIRED      = 'LINK_EXPIRED';

    // Credential__c.Status__c value that permits a new submission.
    private static final String CREDENTIAL_STATUS_REQUESTED    = 'Requested';
    private static final String CREDENTIAL_STATUS_UNDER_REVIEW = 'Under Review';

    // Credential_Request__c.Status__c picklist values for the submission lifecycle.
    // 'Awaiting Submission' is written by the Credential_Request_Creation flow
    // when the parent Credential transitions to Requested.
    // 'Pending Review' is written by this class on a successful volunteer submit.
    private static final String REQUEST_STATUS_AWAITING_SUBMISSION = 'Awaiting Submission';
    private static final String REQUEST_STATUS_PENDING_REVIEW      = 'Pending Review';

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

        /**
         * Salesforce Id of the matched Credential_Request__c. Null unless
         * status = OK. Not currently used by the LWC (submit re-validates by
         * token) but exposed for potential future use without an API change.
         */
        @AuraEnabled public String requestId;

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
     * Looks up a Credential_Request__c by its access token and returns the
     * validation result so the LWC can enter the appropriate state on load.
     *
     * Called imperatively (not via @wire) from the LWC because guest users on
     * LWR Experience Cloud sites cannot use @wire callouts reliably.
     *
     * @param token  The GUID from the ?id= URL parameter. Used as a SOQL bind
     *               variable - never concatenated into the query string.
     * @return       CredentialInfo with status = OK and populated fields when the
     *               request is awaiting submission and the link is unexpired;
     *               otherwise status = INVALID_LINK, ALREADY_SUBMITTED, or
     *               LINK_EXPIRED with all data fields null.
     * @example
     *   CredentialInfo info = CredentialSubmissionController.getCredentialByToken('abc-def');
     *   if (info.status == 'OK') { System.debug(info.credentialType); }
     */
    @AuraEnabled
    public static CredentialInfo getCredentialByToken(String token) {
        List<Credential_Request__c> requests = [
            SELECT  Id,
                    Status__c,
                    CreatedDate,
                    Credential__c,
                    Credential__r.Status__c,
                    Credential__r.Credential_Type__r.Name,
                    Credential__r.Credential_Type__r.Link_Expiry_Days__c,
                    Credential__r.Credential_Type__r.Does_Not_Expire__c
            FROM    Credential_Request__c
            WHERE   Unique_Token__c = :token
            LIMIT   1
        ];

        if (requests.isEmpty()) {
            return buildErrorInfo(STATUS_INVALID_LINK);
        }

        Credential_Request__c request = requests[0];

        // Both conditions are checked to handle edge cases where the request or
        // credential status was manually modified. The primary guard is the
        // request status because that is the value this controller controls.
        if (request.Status__c != REQUEST_STATUS_AWAITING_SUBMISSION
                || request.Credential__r.Status__c != CREDENTIAL_STATUS_REQUESTED) {
            return buildErrorInfo(STATUS_ALREADY_SUBMITTED);
        }

        if (isLinkExpired(request)) {
            return buildErrorInfo(STATUS_LINK_EXPIRED);
        }

        CredentialInfo info  = new CredentialInfo();
        info.status          = STATUS_OK;
        info.requestId       = request.Id;
        info.credentialType  = request.Credential__r.Credential_Type__r.Name;
        info.doesNotExpire   = request.Credential__r.Credential_Type__r.Does_Not_Expire__c;
        return info;
    }

    /**
     * Updates the Credential_Request__c with the volunteer's submission data
     * and marks the parent Credential__c as Under Review.
     *
     * Re-validates the token before any DML so that a submission attempt on an
     * expired or already-used link is rejected even if the page loaded earlier
     * when the link was still valid.
     *
     * In the new token model the Credential_Request__c already exists (created
     * by the Credential_Request_Creation flow). This method updates it rather
     * than creating a new one, so the request Id is stable across the page load
     * and submit lifecycle.
     *
     * @param token       The GUID from the URL - identifies the Credential_Request__c.
     * @param issuedBy    Free-text name of the issuing authority or organisation.
     * @param expiryDate  Date the credential expires. Null for non-expiring types.
     * @return            The Id of the updated Credential_Request__c, which the
     *                    LWC passes to uploadFile for each selected file.
     * @throws AuraHandledException  If the token is no longer valid or DML fails.
     *                               The message is safe to surface in the UI.
     * @example
     *   String requestId = CredentialSubmissionController.submitCredential(
     *       'abc-def', 'Queensland Police', Date.newInstance(2027, 1, 1));
     */
    @AuraEnabled
    public static String submitCredential(String token, String issuedBy, Date expiryDate) {
        List<Credential_Request__c> requests = [
            SELECT  Id,
                    Status__c,
                    CreatedDate,
                    Credential__c,
                    Credential__r.Status__c,
                    Credential__r.Credential_Type__r.Link_Expiry_Days__c
            FROM    Credential_Request__c
            WHERE   Unique_Token__c = :token
            LIMIT   1
        ];

        if (requests.isEmpty()) {
            throw new AuraHandledException(
                'This link is not valid. Please contact your administrator.'
            );
        }

        Credential_Request__c request = requests[0];

        if (request.Status__c != REQUEST_STATUS_AWAITING_SUBMISSION
                || request.Credential__r.Status__c != CREDENTIAL_STATUS_REQUESTED) {
            throw new AuraHandledException('This form has already been submitted.');
        }

        if (isLinkExpired(request)) {
            throw new AuraHandledException(
                'This link has expired. Please contact your administrator to request a new link.'
            );
        }

        try {
            // Update the existing request rather than creating a new one.
            // The Credential_Request_Creation flow already set up this record;
            // we fill in the volunteer's data and advance the status.
            request.Status__c      = REQUEST_STATUS_PENDING_REVIEW;
            request.Issued_By__c   = issuedBy;
            request.Expiry_Date__c = expiryDate;
            update request;

            // Use an Id-only sObject to avoid querying the credential again
            // just to set one field.
            Credential__c credential = new Credential__c(
                Id        = request.Credential__c,
                Status__c = CREDENTIAL_STATUS_UNDER_REVIEW
            );
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
     * Determines whether the submission link has passed its expiry date.
     *
     * Expiry is calculated from the Credential_Request__c CreatedDate rather
     * than a separate date field - the request is created by the flow at the
     * same moment the admin sets Status = Requested, so CreatedDate is the
     * natural start of the expiry window.
     *
     * The cast to Integer is safe because Link_Expiry_Days__c is a required
     * Number field on Credential_Type__c.
     *
     * @param request  Credential_Request__c with CreatedDate and
     *                 Credential__r.Credential_Type__r.Link_Expiry_Days__c populated.
     * @return         True if today is past the expiry date.
     */
    private static Boolean isLinkExpired(Credential_Request__c request) {
        Integer expiryDays = (Integer) request.Credential__r.Credential_Type__r.Link_Expiry_Days__c;
        Date    expiryDate = request.CreatedDate.date().addDays(expiryDays);
        return Date.today() > expiryDate;
    }
}