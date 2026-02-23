/**
 * Invocable Apex action that generates a cryptographically random UUID (GUID).
 *
 * Used by the Credential Token Generation record-triggered flow to populate
 * Unique_Token__c on new Credential__c records. Salesforce Flow has no native
 * GUID function, so this class bridges that gap.
 *
 * Uses Crypto.generateAesKey(128) which produces 128 bits of cryptographic
 * randomness - the same bit-length as a standard UUID v4. This ensures tokens
 * are not guessable or enumerable. See docs/decisions/use-guid-token-for-access-control.md.
 *
 * Does not own: Credential__c DML - the calling flow handles record updates.
 */
public with sharing class GenerateUUID {

    /**
     * Wrapper class for the invocable method output.
     * Using a named output class (rather than a plain List<String> return)
     * so the flow can reference the result by field name rather than an implicit output index.
     */
    public class Result {
        /** The generated UUID string in standard format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx */
        @InvocableVariable(label='UUID' description='Cryptographically random UUID' required=true)
        public String uuid;
    }

    /**
     * Generates one UUID per invocation record. Designed for bulk-safe use in flows -
     * each record in the batch gets its own UUID.
     *
     * @param input  List of placeholder strings, one per invocation. The values are
     *               not used - the list length drives how many UUIDs are generated.
     *               Flow passes an empty string per record.
     * @return       List of Result objects, one per input entry, each containing a UUID.
     * @example
     *   List<GenerateUUID.Result> results = GenerateUUID.generate(new List<String>{ '' });
     *   String token = results[0].uuid; // e.g. 'a3f7b9c1-2d4e-4f8a-b0c2-1e3f5a7b9d0e'
     */
    @InvocableMethod(
        label='Generate UUID'
        description='Generates a cryptographically random UUID for use as a record access token. One UUID is returned per input entry.'
    )
    public static List<Result> generate(List<String> input) {
        List<Result> results = new List<Result>();

        for (String s : input) {
            // Crypto.generateAesKey(128) produces 16 bytes (128 bits) of cryptographic
            // randomness. Converting to hex gives 32 characters which we format as a UUID.
            Blob randomBytes = Crypto.generateAesKey(128);
            String hex = EncodingUtil.convertToHex(randomBytes);

            Result r = new Result();
            // Standard UUID format: 8-4-4-4-12 hex characters separated by hyphens
            r.uuid = hex.substring(0, 8)  + '-' +
                     hex.substring(8, 12)  + '-' +
                     hex.substring(12, 16) + '-' +
                     hex.substring(16, 20) + '-' +
                     hex.substring(20, 32);
            results.add(r);
        }

        return results;
    }
}