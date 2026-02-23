/**
 * Test class for GenerateUUID.
 *
 * Tests behaviour, not implementation - verifies the output format and uniqueness
 * guarantee without asserting anything about the internal crypto mechanism.
 */
@IsTest
private class GenerateUUIDTest {

    /**
     * Happy path: a single invocation returns one correctly formatted UUID.
     */
    @IsTest
    static void generate_singleInput_returnsFormattedUUID() {
        List<String> input = new List<String>{ '' };

        Test.startTest();
        List<GenerateUUID.Result> results = GenerateUUID.generate(input);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Expected one result for one input');

        String uuid = results[0].uuid;
        Assert.isNotNull(uuid, 'UUID should not be null');
        Assert.areEqual(36, uuid.length(), 'UUID should be 36 characters including hyphens');

        // Validate standard UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        Pattern uuidPattern = Pattern.compile(
            '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        );
        Assert.isTrue(
            uuidPattern.matcher(uuid).matches(),
            'UUID should match the standard 8-4-4-4-12 hex format, got: ' + uuid
        );
    }

    /**
     * Uniqueness: two UUIDs generated in the same call should not be identical.
     * This guards against a regression where randomness is seeded with a constant.
     */
    @IsTest
    static void generate_multipleInputs_returnsUniqueValues() {
        List<String> input = new List<String>{ '', '' };

        Test.startTest();
        List<GenerateUUID.Result> results = GenerateUUID.generate(input);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Expected two results for two inputs');
        Assert.areNotEqual(
            results[0].uuid,
            results[1].uuid,
            'Each UUID should be unique - collision suggests non-random generation'
        );
    }

    /**
     * Bulk: 200-record batch completes without hitting governor limits.
     * Record-triggered flows can process up to 200 records per transaction.
     */
    @IsTest
    static void generate_200Records_completesWithinGovernorLimits() {
        List<String> input = new List<String>();
        for (Integer i = 0; i < 200; i++) {
            input.add('');
        }

        Test.startTest();
        List<GenerateUUID.Result> results = GenerateUUID.generate(input);
        Test.stopTest();

        Assert.areEqual(200, results.size(), 'Expected 200 results for 200 inputs');
        for (GenerateUUID.Result r : results) {
            Assert.isNotNull(r.uuid, 'All UUIDs in bulk result should be non-null');
        }
    }
}
