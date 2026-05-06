import { LightningElement, wire, track } from 'lwc';
import getRecordsWithFiles from '@salesforce/apex/FileSearchController.getRecordsWithFiles';
import getAllObjects        from '@salesforce/apex/FileSearchController.getAllObjects';
import uploadFilesToDrive  from '@salesforce/apex/GoogleDriveUploadController.uploadFilesToDrive';
import getAuthUrl          from '@salesforce/apex/GoogleDriveAuthController.getAuthUrl';
import getConnectionStatus from '@salesforce/apex/GoogleDriveAuthController.getConnectionStatus';


export default class GoogleDrive extends LightningElement {
  
    // Object dropdown
    selectedObject;
    objectOptions = [];

    // Files table
    files      = [];
    showNoData = false;

    // Selection tracking
   @track selectedFiles = []; // Selected contentVersionIds array
    allSelected   = false;

    // Google Drive connection
    @track isGoogleConnected = false;

    // ── Google Drive connection status check ─────────────────────────
    @wire(getConnectionStatus)
    wiredStatus({ data, error }) {
        console.log('wiredStatus called');
        if (data) {
            console.log('Google connection status:', data);
            this.isGoogleConnected = data.isConnected;
        }
        if (error) console.error('getConnectionStatus error:', error);
    }

    // ── Component load - postMessage listener register karo ──────────
    connectedCallback() {
        console.log('Component loaded');
        window.addEventListener('message', this.handleMessage.bind(this));
    }

    // ── Popup se OAuth result receive karo ───────────────────────────
    handleMessage(event) {
        console.log('Message received:', event.data);
        if (event.data.type === 'GOOGLE_DRIVE_AUTH_SUCCESS') {
            console.log('Google Connected');
            this.isGoogleConnected = true;
            alert('Google Drive Connected Successfully');
        }
        if (event.data.type === 'GOOGLE_DRIVE_AUTH_ERROR') {
            console.error('Google Auth Error:', event.data.error);
            alert('Error: ' + event.data.error);
        }
    }

    // ── Standard objects dropdown load karo ─────────────────────────
    @wire(getAllObjects)
    wiredObjects({ data, error }) {
        console.log('getAllObjects called');
        if (data) {
            console.log('Objects:', data);
            this.objectOptions  = data.map(obj => ({ label: obj, value: obj }));
            this.selectedObject = data[0];
            console.log('Default object:', this.selectedObject);
        }
        if (error) console.error('getAllObjects error:', error);
    }

    // ── Object dropdown change ────────────────────────────────────────
    handleChange(event) {
        this.selectedObject = event.detail.value;
        console.log('Object changed:', this.selectedObject);
    }

    // ── Search - selected object ki files fetch karo ─────────────────
    handleSearch() {
        console.log('Searching for:', this.selectedObject);
        getRecordsWithFiles({ objectName: this.selectedObject })
            .then(result => {
                console.log('Files fetched:', result);
                console.log('Total files:', result.length);
                console.log('First file contentVersionId:', result.length > 0 ? result[0].contentVersionId : 'N/A');

                // Deep clone - Proxy issue fix
                const cloned = JSON.parse(JSON.stringify(result));
                this.files = cloned.map(f => ({
                    ...f,
                    checked     : false,
                    isSelected  : false,
                    driveLink   : null,
                    uploadError : null
                }));

                this.showNoData   = result.length === 0;
                this.selectedFiles = [];
                this.allSelected   = false;
            })
            .catch(error => {
                console.error('Search error:', error);
            });
    }

    // ── Single row checkbox ───────────────────────────────────────────
    handleCheckbox(event) {
        const id      = event.target.dataset.id;
        const checked = event.target.checked;
        console.log('Checkbox clicked:', id, '| checked:', checked);

        // selectedFiles array mein add/remove karo
        if (checked) {
            this.selectedFiles = [...this.selectedFiles, id];
        } else {
            this.selectedFiles = this.selectedFiles.filter(x => x !== id);
        }

        // Deep clone karke files update karo
        const cloned = JSON.parse(JSON.stringify(this.files));
        cloned.forEach(f => {
            if (f.contentVersionId === id) f.checked = checked;
        });
        this.files = cloned;

        this.allSelected = this.selectedFiles.length === this.files.length;
        console.log('Selected files:', this.selectedFiles);
    }

    // ── Select All checkbox ───────────────────────────────────────────
    handleSelectAll(event) {
        this.allSelected = event.target.checked;
        console.log('Select All:', this.allSelected);

        // Deep clone karke saari files update karo
        const cloned = JSON.parse(JSON.stringify(this.files));
        cloned.forEach(f => f.checked = this.allSelected);
        this.files = cloned;

        // Agar select all toh saare IDs, warna empty
        this.selectedFiles = this.allSelected
            ? this.files.map(f => f.contentVersionId)
            : [];

        console.log('Selected files:', this.selectedFiles);
    }

    // ── Google Drive connect - OAuth popup open karo ──────────────────
    async handleConnect() {
        console.log('Connecting to Google...');
        try {
            const authUrl = await getAuthUrl();
            console.log('Auth URL received');
            window.open(authUrl, '_blank', 'width=600,height=600');
        } catch(e) {
            console.error('Auth error:', e);
            alert('Error opening Google login');
        }
    }

    // ── Upload selected files to Google Drive ─────────────────────────
    handleUpload() {
        console.log('⬆ Upload clicked');
        console.log('Selected:', this.selectedFiles);

        // Koi file select nahi ki
        if (this.selectedFiles.length === 0) {
            console.warn('No files selected');
            alert('Select files first');
            return;
        }

        // Google connected nahi hai toh pehle connect karo
        if (!this.isGoogleConnected) {
            console.warn('Not connected → opening auth');
            this.handleConnect();
            return;
        }

        console.log('Upload starting...');
        console.log('IDs:', this.selectedFiles);

        uploadFilesToDrive({
            contentVersionIds : this.selectedFiles,
            folderId          : null
        })
        .then(result => {
            console.log('Upload success:', result);
            alert('Upload Successful');
        })
        .catch(error => {
            console.error('Upload failed:', error);
            alert('Upload Failed');
        });
    }


    // Selected files ka data modal ko pass karne ke liye
        get filesForUpload() {
            return JSON.parse(JSON.stringify(this.files.filter(f => f.checked)));
        }

    // ── Selected files count getter ───────────────────────────────────
    get selectedCount() {
        return this.selectedFiles.length;
    }
}
