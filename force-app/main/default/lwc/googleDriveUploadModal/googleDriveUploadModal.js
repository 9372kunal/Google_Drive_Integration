// import { LightningElement, api, track } from 'lwc';
// import uploadFilesToDrive from '@salesforce/apex/GoogleDriveUploadController.uploadFilesToDrive';

// export default class GoogleDriveUploadModal extends LightningElement {

//     // Parent se selected ContentVersion IDs aayenge
//     @api selectedFiles = [];
//     @api folderId      = null;

//     @track isModalOpen = false;
//     @track fileList    = [];
//     @track isUploading = false;

//     // Upload summary footer mein dikhata hai
//     get uploadSummary() {
//         const done  = this.fileList.filter(f => f.isDone).length;
//         const total = this.fileList.length;
//         return `${done} of ${total} files uploaded`;
//     }

//     // Modal open karo aur upload start karo
//     handleOpenModal() {
//         console.log('Modal open → selected files:', this.selectedFiles);

//         if (!this.selectedFiles || this.selectedFiles.length === 0) {
//             alert('Pehle files select karo');
//             return;
//         }

//         // File list initialize karo with 0% progress
//         this.fileList = this.selectedFiles.map((f, i) => ({
//             id            : f.contentVersionId || f.id || i,
//             contentVersionId : f.contentVersionId || f,
//             name          : f.fileName || f.name || 'File ' + (i + 1),
//             size          : f.fileSize || '',
//             ext           : (f.fileType || 'FILE').toUpperCase().substring(0, 4),
//             progress      : 0,
//             progressStyle : 'width: 0%',
//             isDone        : false,
//             isError       : false,
//             isUploading   : true
//         }));

//         this.isModalOpen = true;
//         this.isUploading = true;

//         console.log('Starting upload for:', this.fileList.length, 'files');
//         this.startUpload();
//     }

//     // Upload logic - ek ek file upload karo
//     async startUpload() {
//         const ids = this.fileList.map(f => f.contentVersionId);
//         console.log('Upload IDs:', ids);

//         // Har file ke liye alag upload (heap issue fix)
//         for (let i = 0; i < this.fileList.length; i++) {
//             const file = this.fileList[i];
//             console.log('Uploading file:', file.name);

//             // Progress animate karo - 0 se 80% tak
//             await this.animateProgress(i, 0, 80, 600);

//             try {
//                 const results = await uploadFilesToDrive({
//                     contentVersionIds : [file.contentVersionId],
//                     folderId          : this.folderId || null
//                 });

//                 console.log('Upload result for', file.name, ':', results);

//                 const result = results[0];

//                 if (result && result.status === 'success') {
//                     // 80% se 100% tak animate karo
//                     await this.animateProgress(i, 80, 100, 300);
//                     this.updateFile(i, {
//                         isDone      : true,
//                         isUploading : false,
//                         isError     : false,
//                         driveLink   : result.driveLink
//                     });
//                 } else {
//                     this.updateFile(i, {
//                         isDone      : false,
//                         isUploading : false,
//                         isError     : true,
//                         progress    : 100,
//                         progressStyle : 'width: 100%; background: #c23b22;'
//                     });
//                 }

//             } catch (e) {
//                 console.error('Upload error for', file.name, ':', e);
//                 this.updateFile(i, {
//                     isDone      : false,
//                     isUploading : false,
//                     isError     : true,
//                     progress    : 100,
//                     progressStyle : 'width: 100%; background: #c23b22;'
//                 });
//             }
//         }

//         this.isUploading = false;
//         console.log('All uploads done');
//     }

//     // Progress bar smoothly animate karta hai
//     animateProgress(fileIndex, from, to, duration) {
//         return new Promise(resolve => {
//             const steps    = 20;
//             const interval = duration / steps;
//             const step     = (to - from) / steps;
//             let current    = from;
//             let count      = 0;

//             const timer = setInterval(() => {
//                 current += step;
//                 count++;

//                 this.updateFile(fileIndex, {
//                     progress      : Math.round(current),
//                     progressStyle : `width: ${Math.round(current)}%`
//                 });

//                 if (count >= steps) {
//                     clearInterval(timer);
//                     resolve();
//                 }
//             }, interval);
//         });
//     }

//     // Specific file ka data update karo (immutable update)
//     updateFile(index, updates) {
//         const updated = JSON.parse(JSON.stringify(this.fileList));
//         updated[index] = { ...updated[index], ...updates };
//         this.fileList  = updated;
//     }

//     handleCloseModal() {
//         if (this.isUploading) return; // Upload chal raha ho toh close mat karo
//         this.isModalOpen = false;
//         this.fileList    = [];
//         console.log('Modal closed');
//     }
// }


  



import { LightningElement, api, track } from 'lwc';
import uploadSmallFile     from '@salesforce/apex/GoogleDriveUploadController.uploadSmallFile';
import initiateLargeUpload from '@salesforce/apex/GoogleDriveUploadController.initiateLargeUpload';
import uploadChunk         from '@salesforce/apex/GoogleDriveUploadController.uploadChunk';
import ensureTokenFresh    from '@salesforce/apex/GoogleDriveAuthController.ensureTokenFresh';

const CHUNK_SIZE = 4 * 1024 * 1024; // 4MB

export default class GoogleDriveUploadModal extends LightningElement {

    @api selectedFiles = [];
    @api folderId      = null;

    @track isModalOpen = false;
    @track fileList    = [];
    @track isUploading = false;

    get uploadSummary() {
        const done  = this.fileList.filter(f => f.isDone).length;
        const total = this.fileList.length;
        return `${done} of ${total} files uploaded`;
    }

    handleOpenModal() {
        console.log('Modal open → selected files:', this.selectedFiles);

        if (!this.selectedFiles || this.selectedFiles.length === 0) {
            alert('Pehle files select karo');
            return;
        }

        this.fileList = this.selectedFiles.map((f, i) => ({
            id               : f.contentVersionId || i,
            contentVersionId : f.contentVersionId || f,
            name             : f.fileName  || f.name || 'File ' + (i + 1),
            fileSize         : f.fileSize  || f.contentSize || 0,
            ext              : (f.fileType || 'FILE').toUpperCase().substring(0, 4),
            progress         : 0,
            progressStyle    : 'width: 0%',
            isDone           : false,
            isError          : false,
            isUploading      : true,
            driveLink        : null,
            errorMsg         : null
        }));

        this.isModalOpen = true;
        this.isUploading = true;

        console.log('Starting upload for:', this.fileList.length, 'files');
        this.startUpload();
    }

    async startUpload() {
        try {
            // ── STEP 1: Token pehle fresh karo - alag transaction ────
            // Agar token refresh hoga toh DML yahan hoga
            // Upload callout alag transaction mein hoga - conflict nahi
            console.log('Ensuring token is fresh...');
            await ensureTokenFresh();
            console.log('Token ensured - starting uploads');

        } catch(e) {
            console.error('Token ensure failed:', e);
            // Saari files error mark karo
            const updated = JSON.parse(JSON.stringify(this.fileList));
            updated.forEach(f => {
                f.isError     = true;
                f.isUploading = false;
                f.errorMsg    = e.body?.message || 'Token refresh failed';
                f.progressStyle = 'width: 100%; background: #c23b22;';
            });
            this.fileList    = updated;
            this.isUploading = false;
            return;
        }

        // ── STEP 2: Har file upload karo ─────────────────────────────
        for (let i = 0; i < this.fileList.length; i++) {
            const file = this.fileList[i];
            console.log('Processing:', file.name, '| size:', file.fileSize);

            await this.animateProgress(i, 0, 15, 300);

            try {
                if (file.fileSize <= CHUNK_SIZE) {
                    await this.handleSmallFile(i, file);
                } else {
                    await this.handleLargeFile(i, file);
                }
            } catch (e) {
                console.error('Upload error for', file.name, ':', e);
                this.updateFile(i, {
                    isDone        : false,
                    isUploading   : false,
                    isError       : true,
                    errorMsg      : e.body?.message || e.message || 'Upload failed',
                    progressStyle : 'width: 100%; background: #c23b22;'
                });
            }
        }

        this.isUploading = false;
        console.log('All uploads done');
    }

    // Small file upload handler
    async handleSmallFile(i, file) {
        console.log('Small file upload:', file.name);

        const result = await uploadSmallFile({
            contentVersionId : file.contentVersionId,
            folderId         : this.folderId || null
        });

        console.log('Small upload result:', result);

        if (result.status === 'success') {
            await this.animateProgress(i, 15, 100, 400);
            this.updateFile(i, {
                isDone      : true,
                isUploading : false,
                isError     : false,
                driveLink   : result.driveLink
            });
        } else {
            this.updateFile(i, {
                isDone        : false,
                isUploading   : false,
                isError       : true,
                errorMsg      : result.error || 'Upload failed',
                progressStyle : 'width: 100%; background: #c23b22;'
            });
        }
    }

    // Large file chunked upload handler
    async handleLargeFile(i, file) {
        console.log('Large file chunked upload:', file.name);

        // Session initiate karo
        const sessionData = await initiateLargeUpload({
            contentVersionId : file.contentVersionId,
            folderId         : this.folderId || null
        });

        const parts     = sessionData.split('|||');
        const uploadUrl = parts[0];
        const totalSize = parseInt(parts[1], 10);
        const mimeType  = parts[2];

        console.log('Session ready. Size:', totalSize);

        let offset = 0;

        while (offset < totalSize) {
            const progressPct = Math.round(15 + ((offset / totalSize) * 80));
            this.updateFile(i, {
                progress      : progressPct,
                progressStyle : `width: ${progressPct}%`
            });

            console.log('Uploading chunk → offset:', offset, '/', totalSize);

            const chunkResult = await uploadChunk({
                contentVersionId : file.contentVersionId,
                uploadUrl        : uploadUrl,
                mimeType         : mimeType,
                offset           : offset,
                fileSize         : totalSize
            });

            console.log('Chunk result:', chunkResult);

            if (chunkResult.status === 'done') {
                await this.animateProgress(i, progressPct, 100, 300);
                this.updateFile(i, {
                    isDone      : true,
                    isUploading : false,
                    isError     : false,
                    driveLink   : chunkResult.driveLink
                });
                break;

            } else if (chunkResult.status === 'continue') {
                offset = parseInt(chunkResult.nextOffset, 10);

            } else {
                throw new Error(chunkResult.error || 'Chunk upload failed');
            }
        }
    }

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

    updateFile(index, updates) {
        const updated  = JSON.parse(JSON.stringify(this.fileList));
        updated[index] = { ...updated[index], ...updates };
        this.fileList  = updated;
    }

    handleCloseModal() {
        if (this.isUploading) {
            console.warn('Upload in progress - cannot close');
            return;
        }
        this.isModalOpen = false;
        this.fileList    = [];
        console.log('Modal closed');
    }
}