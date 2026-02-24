/**
 * Test class for CredentialSubmissionController.
 *
 * Tests behaviour, not implementation - each test verifies what the system does
 * for a given state of the data, not how the controller achieves it internally.
 *
 * Test data is created in @TestSetup so it is available to all test methods.
 * Each method runs in its own transaction; DML changes are rolled back after
 * the method completes, leaving the @TestSetup data unchanged for other methods.
 *
 * The Credential_Token_Generation record-triggered flow fires After Insert and
 * populates Unique_Token__c on each Credential__c. Token values are therefore
 * not known at insert time and must be queried back via helper methods below.
 */
@IsTest(SeeAllData=false)
private class CredentialSubmissionControllerTest {

    // Label used to identify the test Credential Type across methods.
    private static final String TEST_TYPE_LABEL = 'Test Credential Type';

    // Link expiry window applied to test records - long enough that
    // fresh records are never accidentally expired during test execution.
    private static final Integer LINK_EXPIRY_DAYS = 30;

    // How far back to set Requested_Date__c for the expired credential
    // test case. Double the expiry window ensures the link is definitively
    // past its expiry regardless of execution timing.
    private static final Integer EXPIRED_DAYS_AGO = 60;

    @TestSetup
    static void setupTestData() {
        Credential_Type__c credType = new Credential_Type__c(
            Type__c             = TEST_TYPE_LABEL,
            Link_Expiry_Days__c = LINK_EXPIRY_DAYS,
            Does_Not_Expire__c  = false
        );
        insert credType;

        // Valid credential: Status = Requested, link is fresh.
        // Requested_Date__c is set directly at insert because the Before Update
        // flow that stamps it only fires on status change updates, not inserts.
        Credential__c freshCredential = new Credential__c(
            Credential_Type__c = credType.Id,
            Status__c          = 'Requested',
            Requested_Date__c  = DateTime.now()
        );
        insert freshCredential;

        // Already-submitted credential: Status is no longer Requested.
        Credential__c submittedCredential = new Credential__c(
            Credential_Type__c = credType.Id,
            Status__c          = 'Under Review',
            Requested_Date__c  = DateTime.now()
        );
        insert submittedCredential;

        // Expired credential: Requested_Date__c is well outside the expiry window.
        Credential__c expiredCredential = new Credential__c(
            Credential_Type__c = credType.Id,
            Status__c          = 'Requested',
            Requested_Date__c  = DateTime.now().addDays(-EXPIRED_DAYS_AGO)
        );
        insert expiredCredential;
    }

    /**
     * Returns the Unique_Token__c for the fresh (valid, unexpired) credential.
     * Queries by Status and a recent Requested_Date__c to distinguish it from
     * the expired credential (also Status = Requested but with an old date).
     */
    private static String getFreshToken() {
        Credential__c c = [
            SELECT  Unique_Token__c
            FROM    Credential__c
            WHERE   Status__c = 'Requested'
            AND     Requested_Date__c >= :DateTime.now().addDays(-1)
            LIMIT   1
        ];
        return c.Unique_Token__c;
    }

    /**
     * Returns the Unique_Token__c for the expired credential.
     * Queries by an old Requested_Date__c threshold.
     */
    private static String getExpiredToken() {
        Credential__c c = [
            SELECT  Unique_Token__c
            FROM    Credential__c
            WHERE   Status__c = 'Requested'
            AND     Requested_Date__c <= :DateTime.now().addDays(-LINK_EXPIRY_DAYS)
            LIMIT   1
        ];
        return c.Unique_Token__c;
    }

    /**
     * Returns the Unique_Token__c for the already-submitted credential
     * (Status = Under Review).
     */
    private static String getAlreadySubmittedToken() {
        Credential__c c = [
            SELECT  Unique_Token__c
            FROM    Credential__c
            WHERE   Status__c = 'Under Review'
            LIMIT   1
        ];
        return c.Unique_Token__c;
    }

    // -------------------------------------------------------------------------
    // getCredentialByToken tests
    // -------------------------------------------------------------------------

    /**
     * A valid token on a Requested credential within the expiry window
     * should return status = OK with all credential fields populated.
     */
    @IsTest
    static void getCredentialByToken_validUnexpiredToken_returnsOK() {
        String token = getFreshToken();

        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(token);
        Test.stopTest();

        Assert.areEqual('OK', info.status,
            'Valid unexpired token should return OK status');
        Assert.isNotNull(info.credentialId,
            'credentialId should be populated on OK result');
        Assert.areEqual(TEST_TYPE_LABEL, info.credentialType,
            'credentialType should match the test Credential Type label');
        Assert.isFalse(info.doesNotExpire,
            'doesNotExpire should be false for the test credential type');
    }

    /**
     * A token that does not match any Credential__c record should return
     * status = INVALID_LINK with no data fields populated.
     */
    @IsTest
    static void getCredentialByToken_unknownToken_returnsInvalidLink() {
        // A well-formed GUID that is guaranteed not to match any test record
        String unknownToken = '00000000-0000-0000-0000-000000000000';

        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(unknownToken);
        Test.stopTest();

        Assert.areEqual('INVALID_LINK', info.status,
            'Unknown token should return INVALID_LINK');
        Assert.isNull(info.credentialId,
            'credentialId should be null for an invalid link result');
    }

    /**
     * A token on a credential whose Status is no longer Requested should return
     * status = ALREADY_SUBMITTED, regardless of the expiry date.
     */
    @IsTest
    static void getCredentialByToken_statusNotRequested_returnsAlreadySubmitted() {
        String token = getAlreadySubmittedToken();

        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(token);
        Test.stopTest();

        Assert.areEqual('ALREADY_SUBMITTED', info.status,
            'Non-Requested status should return ALREADY_SUBMITTED');
    }

    /**
     * A token on a credential whose Requested_Date__c is past the expiry
     * window should return status = LINK_EXPIRED.
     */
    @IsTest
    static void getCredentialByToken_expiredRequestedDate_returnsLinkExpired() {
        String token = getExpiredToken();

        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(token);
        Test.stopTest();

        Assert.areEqual('LINK_EXPIRED', info.status,
            'Expired Requested_Date__c should return LINK_EXPIRED');
    }

    // -------------------------------------------------------------------------
    // submitCredential tests
    // -------------------------------------------------------------------------

    /**
     * A valid submission should create a Credential_Request__c with the
     * submitted values, update the Credential Status to Under Review, and
     * return the new request Id.
     */
    @IsTest
    static void submitCredential_validToken_createsRequestAndUpdatesCredential() {
        String token         = getFreshToken();
        String issuedBy      = 'Queensland Police';
        Date   expiry        = Date.today().addYears(1);

        Test.startTest();
        String requestId = CredentialSubmissionController.submitCredential(
            token, issuedBy, expiry
        );
        Test.stopTest();

        Assert.isNotNull(requestId, 'submitCredential should return the new request Id');

        Credential_Request__c request = [
            SELECT Credential__c, Status__c, Issued_By__c, Expiry_Date__c
            FROM   Credential_Request__c
            WHERE  Id = :requestId
        ];
        Assert.areEqual('Pending Review', request.Status__c,
            'New request Status should be Pending Review');
        Assert.areEqual(issuedBy, request.Issued_By__c,
            'Issued_By__c should match the submitted value');
        Assert.areEqual(expiry, request.Expiry_Date__c,
            'Expiry_Date__c should match the submitted value');

        Credential__c credential = [
            SELECT Status__c
            FROM   Credential__c
            WHERE  Unique_Token__c = :token
        ];
        Assert.areEqual('Under Review', credential.Status__c,
            'Credential Status should be Under Review after a successful submission');
    }

    /**
     * Submitting with a token whose Credential is no longer Requested (stale
     * between page load and form submit) should throw AuraHandledException.
     */
    @IsTest
    static void submitCredential_staleToken_throwsAuraHandledException() {
        String token = getAlreadySubmittedToken();

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CredentialSubmissionController.submitCredential(token, 'Test Issuer', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'submitCredential with a stale token should throw AuraHandledException');
    }

    // -------------------------------------------------------------------------
    // uploadFile tests
    // -------------------------------------------------------------------------

    /**
     * Uploading a valid base64 file to a real Credential_Request__c should
     * create a ContentVersion with the correct Title linked to the request.
     */
    @IsTest
    static void uploadFile_validRequest_createsContentVersion() {
        // Create the prerequisite Credential_Request__c directly to isolate
        // this test from submitCredential behaviour.
        Credential__c credential = [
            SELECT Id
            FROM   Credential__c
            WHERE  Status__c = 'Requested'
            AND    Requested_Date__c >= :DateTime.now().addDays(-1)
            LIMIT  1
        ];
        Credential_Request__c request = new Credential_Request__c(
            Credential__c = credential.Id,
            Status__c     = 'Pending Review'
        );
        insert request;

        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('test file content'));

        Test.startTest();
        CredentialSubmissionController.uploadFile(
            request.Id, 'police-check.pdf', base64Content
        );
        Test.stopTest();

        List<ContentVersion> versions = [
            SELECT Title, PathOnClient
            FROM   ContentVersion
            WHERE  FirstPublishLocationId = :request.Id
        ];
        Assert.areEqual(1, versions.size(),
            'Exactly one ContentVersion should be created per uploadFile call');
        Assert.areEqual('police-check.pdf', versions[0].Title,
            'ContentVersion Title should match the submitted file name');
        Assert.areEqual('police-check.pdf', versions[0].PathOnClient,
            'ContentVersion PathOnClient should match the submitted file name');
    }

    /**
     * Passing a requestId that does not refer to any Credential_Request__c
     * should throw AuraHandledException to prevent attaching files to
     * arbitrary records.
     */
    @IsTest
    static void uploadFile_invalidRequestId_throwsAuraHandledException() {
        // Use a Credential_Type__c Id as a wrong-type record reference.
        // The SOQL query on Credential_Request__c will return empty results
        // because no Credential_Request__c has this Id.
        Credential_Type__c credType = [SELECT Id FROM Credential_Type__c LIMIT 1];

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CredentialSubmissionController.uploadFile(
                credType.Id, 'test.pdf', 'dGVzdA=='
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'uploadFile with a non-existent requestId should throw AuraHandledException');
    }
}