/**
 * Test class for CredentialSubmissionController.
 *
 * Tests behaviour, not implementation - each test verifies what the system does
 * for a given state of the data, not how the controller achieves it internally.
 *
 * Test data strategy (post phase-4 restructure):
 *   Tokens now live on Credential_Request__c, not Credential__c. Hard-coded
 *   UUID-shaped tokens are inserted directly on Credential_Request__c records
 *   in @TestSetup, so each test method can reference them by constant without
 *   needing to query them back.
 *
 *   Link expiry is based on Credential_Request__c.CreatedDate, which cannot be
 *   set in Apex tests. The expired scenario is achieved by using a separate
 *   Credential_Type__c with Link_Expiry_Days__c = -1: expiry = today - 1 day,
 *   which is always in the past regardless of when the test runs.
 *
 * Each test method runs in its own transaction; DML changes are rolled back
 * after the method completes, leaving the @TestSetup data unchanged.
 */
@IsTest(SeeAllData=false)
private class CredentialSubmissionControllerTest {

    // Label used to identify the standard test Credential Type across methods.
    private static final String TEST_TYPE_LABEL = 'Test Credential Type';

    // Link expiry for the normal credential type - long enough that records
    // created in @TestSetup are never accidentally expired during test execution.
    private static final Integer LINK_EXPIRY_DAYS = 30;

    // Hard-coded tokens inserted on the test Credential_Request__c records.
    // UUID-shaped so they satisfy Text(36); clearly fake so they cannot
    // collide with real org data.
    private static final String FRESH_TOKEN     = '00000000-0000-0000-0000-000000000001';
    private static final String SUBMITTED_TOKEN = '00000000-0000-0000-0000-000000000002';
    private static final String EXPIRED_TOKEN   = '00000000-0000-0000-0000-000000000003';

    @TestSetup
    static void setupTestData() {
        // Standard credential type used for the fresh and submitted scenarios.
        Credential_Type__c credType = new Credential_Type__c(
            Name                = TEST_TYPE_LABEL,
            Link_Expiry_Days__c = LINK_EXPIRY_DAYS,
            Does_Not_Expire__c  = false
        );

        // Credential type for the expiry scenario. Link_Expiry_Days__c = -1
        // means expiry = CreatedDate - 1 day, which is always yesterday, so
        // isLinkExpired always returns true without needing to control CreatedDate.
        Credential_Type__c expiredCredType = new Credential_Type__c(
            Name                = 'Expired Test Credential Type',
            Link_Expiry_Days__c = -1,
            Does_Not_Expire__c  = false
        );

        insert new List<Credential_Type__c>{ credType, expiredCredType };

        // Credentials inserted with Status = Requested at insert time.
        // The Credential_Request_Creation flow only fires on After Update,
        // so inserting here does not create any unintended request records.
        Credential__c freshCredential = new Credential__c(
            Credential_Type__c = credType.Id,
            Status__c          = 'Requested'
        );
        Credential__c submittedCredential = new Credential__c(
            Credential_Type__c = credType.Id,
            Status__c          = 'Requested'
        );
        Credential__c expiredCredential = new Credential__c(
            Credential_Type__c = expiredCredType.Id,
            Status__c          = 'Requested'
        );

        insert new List<Credential__c>{
            freshCredential, submittedCredential, expiredCredential
        };

        // Request records inserted with hard-coded tokens to make token values
        // predictable across all test methods.
        //
        // Fresh: Awaiting Submission - the standard valid state a volunteer sees.
        // Submitted: Pending Review - simulates a request already actioned.
        // Expired: Awaiting Submission but Credential_Type uses Link_Expiry_Days__c = -1.
        insert new List<Credential_Request__c>{
            new Credential_Request__c(
                Credential__c   = freshCredential.Id,
                Status__c       = 'Awaiting Submission',
                Unique_Token__c = FRESH_TOKEN
            ),
            new Credential_Request__c(
                Credential__c   = submittedCredential.Id,
                Status__c       = 'Pending Review',
                Unique_Token__c = SUBMITTED_TOKEN
            ),
            new Credential_Request__c(
                Credential__c   = expiredCredential.Id,
                Status__c       = 'Awaiting Submission',
                Unique_Token__c = EXPIRED_TOKEN
            )
        };
    }

    // -------------------------------------------------------------------------
    // getCredentialByToken tests
    // -------------------------------------------------------------------------

    /**
     * A valid token on an Awaiting Submission request within the expiry window
     * should return status = OK with all credential fields populated.
     */
    @IsTest
    static void getCredentialByToken_validUnexpiredToken_returnsOK() {
        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(FRESH_TOKEN);
        Test.stopTest();

        Assert.areEqual('OK', info.status,
            'Valid unexpired token should return OK status');
        Assert.isNotNull(info.requestId,
            'requestId should be populated on OK result');
        Assert.areEqual(TEST_TYPE_LABEL, info.credentialType,
            'credentialType should match the test Credential Type label');
        Assert.isFalse(info.doesNotExpire,
            'doesNotExpire should be false for the test credential type');
    }

    /**
     * A token that does not match any Credential_Request__c record should
     * return status = INVALID_LINK with no data fields populated.
     */
    @IsTest
    static void getCredentialByToken_unknownToken_returnsInvalidLink() {
        // A well-formed GUID that is guaranteed not to match any test record.
        String unknownToken = '00000000-0000-0000-0000-000000000000';

        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(unknownToken);
        Test.stopTest();

        Assert.areEqual('INVALID_LINK', info.status,
            'Unknown token should return INVALID_LINK');
        Assert.isNull(info.requestId,
            'requestId should be null for an invalid link result');
    }

    /**
     * A token on a request whose Status is no longer Awaiting Submission should
     * return status = ALREADY_SUBMITTED, regardless of the expiry date.
     */
    @IsTest
    static void getCredentialByToken_requestAlreadyActioned_returnsAlreadySubmitted() {
        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(SUBMITTED_TOKEN);
        Test.stopTest();

        Assert.areEqual('ALREADY_SUBMITTED', info.status,
            'Request with status Pending Review should return ALREADY_SUBMITTED');
    }

    /**
     * A token on a request whose linked Credential_Type has Link_Expiry_Days__c = -1
     * (i.e. always expired relative to today) should return status = LINK_EXPIRED.
     */
    @IsTest
    static void getCredentialByToken_negativeExpiryDays_returnsLinkExpired() {
        Test.startTest();
        CredentialSubmissionController.CredentialInfo info =
            CredentialSubmissionController.getCredentialByToken(EXPIRED_TOKEN);
        Test.stopTest();

        Assert.areEqual('LINK_EXPIRED', info.status,
            'Request on a credential type with Link_Expiry_Days__c = -1 should return LINK_EXPIRED');
    }

    // -------------------------------------------------------------------------
    // submitCredential tests
    // -------------------------------------------------------------------------

    /**
     * A valid submission should update the Credential_Request__c with the
     * submitted values, update the Credential Status to Under Review, and
     * return the request Id.
     */
    @IsTest
    static void submitCredential_validToken_updatesRequestAndCredential() {
        String issuedBy = 'Queensland Police';
        Date   expiry   = Date.today().addYears(1);

        Test.startTest();
        String requestId = CredentialSubmissionController.submitCredential(
            FRESH_TOKEN, issuedBy, expiry
        );
        Test.stopTest();

        Assert.isNotNull(requestId, 'submitCredential should return the request Id');

        Credential_Request__c request = [
            SELECT Credential__c, Status__c, Issued_By__c, Expiry_Date__c
            FROM   Credential_Request__c
            WHERE  Id = :requestId
        ];
        Assert.areEqual('Pending Review', request.Status__c,
            'Request Status should be updated to Pending Review');
        Assert.areEqual(issuedBy, request.Issued_By__c,
            'Issued_By__c should match the submitted value');
        Assert.areEqual(expiry, request.Expiry_Date__c,
            'Expiry_Date__c should match the submitted value');

        Credential__c credential = [
            SELECT Status__c
            FROM   Credential__c
            WHERE  Id = :request.Credential__c
        ];
        Assert.areEqual('Under Review', credential.Status__c,
            'Credential Status should be Under Review after a successful submission');
    }

    /**
     * Submitting with a token whose request is no longer Awaiting Submission
     * (stale between page load and form submit) should throw AuraHandledException.
     */
    @IsTest
    static void submitCredential_staleToken_throwsAuraHandledException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CredentialSubmissionController.submitCredential(SUBMITTED_TOKEN, 'Test Issuer', null);
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
