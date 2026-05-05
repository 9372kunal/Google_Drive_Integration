import { LightningElement, wire, track } from 'lwc';
import getRecordsWithFiles from '@salesforce/apex/FileSearchController.getRecordsWithFiles';
import getAllObjects from '@salesforce/apex/FileSearchController.getAllObjects';
import uploadFilesToDrive from '@salesforce/apex/GoogleDriveUploadController.uploadFilesToDrive';

import getAuthUrl from '@salesforce/apex/GoogleDriveAuthController.getAuthUrl';
import getConnectionStatus from '@salesforce/apex/GoogleDriveAuthController.getConnectionStatus';

export default class GoogleDrive extends LightningElement {

    selectedObject;
    objectOptions = [];
    files = [];
    showNoData = false;

    selectedFiles = [];
    allSelected = false;

    @track isGoogleConnected = false;

    // ✅ Check connection automatically
    @wire(getConnectionStatus)
    wiredStatus({ data }) {
        if (data) {
            this.isGoogleConnected = data.isConnected;
        }
    }

    connectedCallback() {
        window.addEventListener('message', this.handleMessage.bind(this));
    }

    handleMessage(event) {
        if (event.data.type === 'GOOGLE_DRIVE_AUTH_SUCCESS') {
            this.isGoogleConnected = true;
            alert('Google Drive Connected Successfully');
        }

        if (event.data.type === 'GOOGLE_DRIVE_AUTH_ERROR') {
            alert('Error: ' + event.data.error);
        }
    }

    @wire(getAllObjects)
    wiredObjects({ data }) {
        if (data) {
            this.objectOptions = data.map(obj => ({
                label: obj,
                value: obj
            }));
            this.selectedObject = data[0];
        }
    }

    handleChange(event){
        this.selectedObject = event.detail.value;
    }

    handleSearch(){
        getRecordsWithFiles({ objectName: this.selectedObject })
        .then(result => {
            this.files = result;
            this.showNoData = result.length === 0;

            this.selectedFiles = [];
            this.allSelected = false;
        });
    }

    handleCheckbox(event){
        const id = event.target.dataset.id;
        const checked = event.target.checked;

        if(checked){
            this.selectedFiles = [...this.selectedFiles, id];
        } else {
            this.selectedFiles = this.selectedFiles.filter(x => x !== id);
        }

        this.files = this.files.map(file => {
            if(file.contentVersionId === id){
                return { ...file, checked: checked };
            }
            return file;
        });

        this.allSelected = this.selectedFiles.length === this.files.length;
    }

    handleSelectAll(event){
        this.allSelected = event.target.checked;

        if(this.allSelected){
            this.selectedFiles = this.files.map(f => f.contentVersionId);
        } else {
            this.selectedFiles = [];
        }

        this.files = this.files.map(file => {
            return { ...file, checked: this.allSelected };
        });
    }

    // ✅ Connect Google
    async handleConnect(){
        try {
            const authUrl = await getAuthUrl();
            window.open(authUrl, '_blank', 'width=600,height=600');
        } catch(e){
            console.error(e);
            alert('Error opening Google login');
        }
    }

    // ✅ Upload
    handleUpload(){

        if(this.selectedFiles.length === 0){
            alert('Select files first');
            return;
        }

        if(!this.isGoogleConnected){
            this.handleConnect();
            return;
        }

        uploadFilesToDrive({
            contentVersionIds: this.selectedFiles,
            folderId: null
        })
        .then(result => {
            console.log('Upload Result:', result);
            alert('Upload Successful 🚀');
        })
        .catch(error => {
            console.error(error);
            alert('Upload Failed ❌');
        });
    }

    get selectedCount(){
        return this.selectedFiles.length;
    }
}