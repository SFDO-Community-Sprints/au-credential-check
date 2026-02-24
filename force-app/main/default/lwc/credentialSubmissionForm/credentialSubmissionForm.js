/**
 * Credential submission form for the LWR Experience Cloud site.
 *
 * Reads the ?id= token from the current page URL, validates it against the
 * Credential__c record via Apex, then presents the intake form or an appropriate
 * error screen. On submit, creates a Credential_Request__c staging record and
 * uploads any attached files via Apex (base64) to avoid guest user file
 * permission complications on LWR sites.
 *
 * Coexists with the Credential_Intake_Form screen flow - both paths produce the
 * same Credential_Request__c outcome. Neither replaces the other.
 *
 * Does not own: Credential_Request_Approval flow logic, Experience Cloud site
 * configuration, or Guest User profile permissions.
 */
import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCredentialByToken from '@salesforce/apex/CredentialSubmissionController.getCredentialByToken';
import submitCredential from '@salesforce/apex/CredentialSubmissionController.submitCredential';
import uploadFile from '@salesforce/apex/CredentialSubmissionController.uploadFile';

// Maximum raw file size before base64 encoding. Base64 expands by ~33%, so
// 4 MB raw produces ~5.3 MB encoded. The Apex heap limit is 6 MB; staying
// below 4 MB raw provides safe headroom for a single file plus call overhead.
const MAX_FILE_SIZE_BYTES = 4 * 1024 * 1024;

// State machine values. String literals used rather than an enum because LWC
// template conditionals compare against JavaScript primitives. These values
// must match the status codes returned by getCredentialByToken in Apex.
const STATE_LOADING           = 'LOADING';
const STATE_INVALID_LINK      = 'INVALID_LINK';
const STATE_ALREADY_SUBMITTED = 'ALREADY_SUBMITTED';
const STATE_LINK_EXPIRED      = 'LINK_EXPIRED';
const STATE_FORM              = 'FORM';
const STATE_SUBMITTING        = 'SUBMITTING';
const STATE_SUCCESS           = 'SUCCESS';

// Maps each error state to the heading and body text displayed to the volunteer.
// Centralised here so message copy can be updated without touching the template.
const STATE_MESSAGES = {
    [STATE_INVALID_LINK]: {
        heading: 'Link Not Valid',
        message: 'This link is not valid. Please check the URL or contact your administrator.'
    },
    [STATE_ALREADY_SUBMITTED]: {
        heading: 'Already Submitted',
        message: 'This credential has already been submitted for review. No further action is needed.'
    },
    [STATE_LINK_EXPIRED]: {
        heading: 'Link Expired',
        message: 'This submission link has expired. Please contact your administrator to request a new link.'
    }
};

export default class CredentialSubmissionForm extends LightningElement {

    // --- State machine ---
    _state = STATE_LOADING;

    // --- Credential data loaded from Apex on token validation ---
    _credentialType = '';
    _doesNotExpire  = false;

    // --- Form field values ---
    _issuedBy   = '';
    _expiryDate = '';

    // --- Files selected by the volunteer ---
    // Array of { name: String, size: Number, sizeFormatted: String, base64: String }
    _selectedFiles = [];

    // --- Inline error message shown on validation or submit failure ---
    _errorMessage = '';

    // --- Token extracted from the ?id= URL parameter ---
    // Initialised to undefined (not null) so the change guard in handlePageRef
    // correctly detects the first wire provisioning even when the token is absent
    // (null !== undefined → true on first call).
    _token = undefined;

    /**
     * Wire method called by the framework when the page reference is first
     * available and whenever it changes.
     *
     * Extracts the ?id= token from the URL state and triggers the credential
     * validation Apex call. Using a wire method (rather than a wire property)
     * ensures _loadCredential fires immediately when the value is provisioned.
     * Note: @wire cannot be applied to getter/setter accessors - a regular
     * method is required.
     *
     * @param {Object} pageRef - the LWR CurrentPageReference object.
     */
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef) return;
        const token = pageRef?.state?.id ?? null;
        // Guard against re-loading when the page reference updates for a reason
        // unrelated to our token (e.g. Experience Builder state changes).
        // The undefined initial value ensures this guard passes on the very
        // first wire provisioning even when no ?id= param is present.
        if (token !== this._token) {
            this._token = token;
            this._loadCredential();
        }
    }

    /**
     * Calls getCredentialByToken imperatively and drives the state machine.
     *
     * @wire is not used because the LWC runs as an unauthenticated guest user
     * and reactive wire adapters do not reliably support Apex callouts in that
     * context on LWR sites.
     */
    _loadCredential() {
        if (!this._token) {
            this._state = STATE_INVALID_LINK;
            return;
        }
        this._state = STATE_LOADING;
        getCredentialByToken({ token: this._token })
            .then(result => {
                if (result.status === 'OK') {
                    this._credentialType = result.credentialType;
                    this._doesNotExpire  = result.doesNotExpire;
                    this._state          = STATE_FORM;
                } else {
                    // INVALID_LINK, ALREADY_SUBMITTED, and LINK_EXPIRED are
                    // returned as status codes rather than thrown exceptions so
                    // the LWC can map them to tailored messages without parsing
                    // exception text.
                    this._state = result.status;
                }
            })
            .catch(() => {
                // A network or server error at load time is surfaced as an
                // invalid link - the volunteer cannot proceed and the message
                // directs them to their administrator.
                this._state = STATE_INVALID_LINK;
            });
    }

    // --- Form field event handlers ---

    handleIssuedByChange(event) {
        this._issuedBy = event.target.value;
    }

    handleExpiryDateChange(event) {
        this._expiryDate = event.target.value;
    }

    /**
     * Processes the files selected by the volunteer.
     *
     * Validates each file against the size limit, then reads it as a base64
     * data URI using FileReader. The data URI prefix ("data:<mime>;base64,")
     * is stripped so only raw base64 is stored - that is what Apex's
     * EncodingUtil.base64Decode expects.
     *
     * Each FileReader.onload callback reassigns _selectedFiles to a new array,
     * which triggers an LWC re-render to update the file list in the template.
     *
     * @param {Event} event - the change event from the native file input.
     */
    handleFileChange(event) {
        const files = Array.from(event.target.files);
        this._selectedFiles = [];
        this._errorMessage  = '';

        files.forEach(file => {
            if (file.size > MAX_FILE_SIZE_BYTES) {
                this._errorMessage =
                    `"${file.name}" exceeds the 4 MB limit and was not added.`;
                return;
            }
            const reader = new FileReader();
            reader.onload = () => {
                // Split on the first comma to discard the data URI prefix and
                // keep only the base64-encoded content.
                const base64 = reader.result.split(',')[1];
                this._selectedFiles = [
                    ...this._selectedFiles,
                    {
                        name:          file.name,
                        size:          file.size,
                        sizeFormatted: this._formatFileSize(file.size),
                        base64
                    }
                ];
            };
            reader.readAsDataURL(file);
        });
    }

    /**
     * Validates the form and orchestrates the full submission sequence.
     *
     * Sequence:
     *   1. Validate required fields client-side.
     *   2. Call submitCredential (creates Credential_Request__c, updates Credential).
     *   3. Call uploadFile once per selected file, sequentially.
     *   4. Set state to SUCCESS.
     *
     * Files are uploaded sequentially rather than concurrently to avoid heap
     * pressure from multiple large base64 payloads being decoded simultaneously
     * in the Apex execution context.
     *
     * On any failure the error is displayed inline and state returns to FORM
     * so the volunteer can retry without losing their entered data.
     */
    async handleSubmit() {
        this._errorMessage = '';

        if (!this._issuedBy.trim()) {
            this._errorMessage = 'Issued By is required.';
            return;
        }

        if (this.showExpiryDate && !this._expiryDate) {
            this._errorMessage = 'Expiry Date is required.';
            return;
        }

        if (this._selectedFiles.length === 0) {
            this._errorMessage = 'Please select at least one supporting document.';
            return;
        }

        this._state = STATE_SUBMITTING;

        try {
            const requestId = await submitCredential({
                token:      this._token,
                issuedBy:   this._issuedBy.trim(),
                expiryDate: this.showExpiryDate ? this._expiryDate : null
            });

            for (const file of this._selectedFiles) {
                // Sequential await is intentional - see JSDoc above.
                // eslint-disable-next-line no-await-in-loop
                await uploadFile({
                    requestId,
                    fileName:   file.name,
                    base64Data: file.base64
                });
            }

            this._state = STATE_SUCCESS;

        } catch (error) {
            const message = error?.body?.message
                ?? 'An unexpected error occurred. Please try again.';
            this._errorMessage = message;
            this._state        = STATE_FORM;
        }
    }

    // --- Template getters ---

    /** True while the initial Apex token validation call is in flight. */
    get isLoading() {
        return this._state === STATE_LOADING;
    }

    /** True for any of the three terminal error states. */
    get isInvalidState() {
        return this._state === STATE_INVALID_LINK
            || this._state === STATE_ALREADY_SUBMITTED
            || this._state === STATE_LINK_EXPIRED;
    }

    /** True when the volunteer is actively filling out the form. */
    get isForm() {
        return this._state === STATE_FORM;
    }

    /** True while Apex submit and upload calls are in flight. */
    get isSubmitting() {
        return this._state === STATE_SUBMITTING;
    }

    /** True after all Apex calls complete successfully. */
    get isSuccess() {
        return this._state === STATE_SUCCESS;
    }

    /** Display label for the credential type, shown in the form header. */
    get credentialType() {
        return this._credentialType;
    }

    /**
     * Controls visibility of the Expiry Date input.
     * Hidden when the credential type is configured as non-expiring.
     */
    get showExpiryDate() {
        return !this._doesNotExpire;
    }

    /** Current Issued By value, used as the initial input value. */
    get issuedBy() {
        return this._issuedBy;
    }

    /** Current Expiry Date value, used as the initial input value. */
    get expiryDate() {
        return this._expiryDate;
    }

    /** File objects for the template list rendering. */
    get selectedFiles() {
        return this._selectedFiles;
    }

    /** True when at least one file has been selected and read. */
    get hasFiles() {
        return this._selectedFiles.length > 0;
    }

    /** Inline error message shown in the form; empty string hides the alert. */
    get errorMessage() {
        return this._errorMessage;
    }

    /** Heading text for the current error state card. */
    get stateHeading() {
        return STATE_MESSAGES[this._state]?.heading ?? '';
    }

    /** Body text for the current error state card. */
    get stateMessage() {
        return STATE_MESSAGES[this._state]?.message ?? '';
    }

    // --- Private helpers ---

    /**
     * Converts a raw byte count to a human-readable size string.
     *
     * @param {number} bytes - file size in bytes.
     * @returns {string} e.g. "2.4 MB" or "512 KB".
     */
    _formatFileSize(bytes) {
        if (bytes >= 1024 * 1024) {
            return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
        }
        return `${Math.round(bytes / 1024)} KB`;
    }
}
