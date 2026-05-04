import { LightningElement,wire} from 'lwc';
import getRecordsWithFiles from '@salesforce/apex/FileSearchController.getRecordsWithFiles';
import getAllObjects from '@salesforce/apex/FileSearchController.getAllObjects';
export default class GoogleDrive extends LightningElement {

     selectedObject;
    objectOptions = [];
    files = [];
    showNoData = false;

    selectedFiles = [];
    allSelected = false;

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
        const fileId = event.target.dataset.id;
        const checked = event.target.checked;

        if(checked){
            this.selectedFiles = [...this.selectedFiles, fileId];
        } else {
            this.selectedFiles = this.selectedFiles.filter(id => id !== fileId);
        }

        this.files = this.files.map(file => {
            if(file.fileId === fileId){
                return { ...file, checked: checked };
            }
            return file;
        });

        this.allSelected = this.selectedFiles.length === this.files.length;
    }

    handleSelectAll(event){
        this.allSelected = event.target.checked;

        if(this.allSelected){
            this.selectedFiles = this.files.map(f => f.fileId);
        } else {
            this.selectedFiles = [];
        }

        this.files = this.files.map(file => {
            return { ...file, checked: this.allSelected };
        });
    }

    handleDownloadSelected(){

        if(this.selectedFiles.length === 0){
            alert('Select at least one file');
            return;
        }

        let i = 0;

        const downloadNext = () => {
            if(i >= this.selectedFiles.length){
                return;
            }

            const fileId = this.selectedFiles[i];

            window.open(`/sfc/servlet.shepherd/document/download/${fileId}`, '_blank');

            i++;

            setTimeout(downloadNext, 800);
        };

        downloadNext();
    }

    handleUpload(){
        if(this.selectedFiles.length === 0){
            alert('Select files first');
            return;
        }
.
        alert('Google Drive Upload Next Step 🚀');
    }

    get selectedCount(){
        return this.selectedFiles.length;
    }
}