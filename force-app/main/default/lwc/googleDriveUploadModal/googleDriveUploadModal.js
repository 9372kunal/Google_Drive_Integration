import { LightningElement, api, track } from 'lwc';
import uploadFilesToDrive from '@salesforce/apex/GoogleDriveUploadController.uploadFilesToDrive';

export default class GoogleDriveUploadModal extends LightningElement {

    // Parent se selected ContentVersion IDs aayenge
    @api selectedFiles = [];
    @api folderId      = null;

    @track isModalOpen = false;
    @track fileList    = [];
    @track isUploading = false;

    // Upload summary footer mein dikhata hai
    get uploadSummary() {
        const done  = this.fileList.filter(f => f.isDone).length;
        const total = this.fileList.length;
        return `${done} of ${total} files uploaded`;
    }

    // Modal open karo aur upload start karo
    handleOpenModal() {
        console.log('Modal open → selected files:', this.selectedFiles);

        if (!this.selectedFiles || this.selectedFiles.length === 0) {
            alert('Pehle files select karo');
            return;
        }

        // File list initialize karo with 0% progress
        this.fileList = this.selectedFiles.map((f, i) => ({
            id            : f.contentVersionId || f.id || i,
            contentVersionId : f.contentVersionId || f,
            name          : f.fileName || f.name || 'File ' + (i + 1),
            size          : f.fileSize || '',
            ext           : (f.fileType || 'FILE').toUpperCase().substring(0, 4),
            progress      : 0,
            progressStyle : 'width: 0%',
            isDone        : false,
            isError       : false,
            isUploading   : true
        }));

        this.isModalOpen = true;
        this.isUploading = true;

        console.log('Starting upload for:', this.fileList.length, 'files');
        this.startUpload();
    }

    // Upload logic - ek ek file upload karo
    async startUpload() {
        const ids = this.fileList.map(f => f.contentVersionId);
        console.log('Upload IDs:', ids);

        // Har file ke liye alag upload (heap issue fix)
        for (let i = 0; i < this.fileList.length; i++) {
            const file = this.fileList[i];
            console.log('Uploading file:', file.name);

            // Progress animate karo - 0 se 80% tak
            await this.animateProgress(i, 0, 80, 600);

            try {
                const results = await uploadFilesToDrive({
                    contentVersionIds : [file.contentVersionId],
                    folderId          : this.folderId || null
                });

                console.log('Upload result for', file.name, ':', results);

                const result = results[0];

                if (result && result.status === 'success') {
                    // 80% se 100% tak animate karo
                    await this.animateProgress(i, 80, 100, 300);
                    this.updateFile(i, {
                        isDone      : true,
                        isUploading : false,
                        isError     : false,
                        driveLink   : result.driveLink
                    });
                } else {
                    this.updateFile(i, {
                        isDone      : false,
                        isUploading : false,
                        isError     : true,
                        progress    : 100,
                        progressStyle : 'width: 100%; background: #c23b22;'
                    });
                }

            } catch (e) {
                console.error('Upload error for', file.name, ':', e);
                this.updateFile(i, {
                    isDone      : false,
                    isUploading : false,
                    isError     : true,
                    progress    : 100,
                    progressStyle : 'width: 100%; background: #c23b22;'
                });
            }
        }

        this.isUploading = false;
        console.log('All uploads done');
    }

    // Progress bar smoothly animate karta hai
    animateProgress(fileIndex, from, to, duration) {
        return new Promise(resolve => {
            const steps    = 20;
            const interval = duration / steps;
            const step     = (to - from) / steps;
            let current    = from;
            let count      = 0;

            const timer = setInterval(() => {
                current += step;
                count++;

                this.updateFile(fileIndex, {
                    progress      : Math.round(current),
                    progressStyle : `width: ${Math.round(current)}%`
                });

                if (count >= steps) {
                    clearInterval(timer);
                    resolve();
                }
            }, interval);
        });
    }

    // Specific file ka data update karo (immutable update)
    updateFile(index, updates) {
        const updated = JSON.parse(JSON.stringify(this.fileList));
        updated[index] = { ...updated[index], ...updates };
        this.fileList  = updated;
    }

    handleCloseModal() {
        if (this.isUploading) return; // Upload chal raha ho toh close mat karo
        this.isModalOpen = false;
        this.fileList    = [];
        console.log('Modal closed');
    }
}