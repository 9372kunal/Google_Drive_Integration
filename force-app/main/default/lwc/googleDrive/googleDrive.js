import { LightningElement,wire} from 'lwc';
import getRecordsWithFiles from '@salesforce/apex/FileSearchController.getRecordsWithFiles';
import getAllObjects from '@salesforce/apex/FileSearchController.getAllObjects';
export default class GoogleDrive extends LightningElement {

     selectedObject;
    objectOptions = [];
    files = [];
    showNoData = false;

    // 🔥 Load ALL Standard Objects
    @wire(getAllObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data.map(obj => {
                return { label: obj, value: obj };
            });

            // default select first
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

            // ✅ Show No Data if empty
            this.showNoData = result.length === 0;
        })
        .catch(error => {
            console.error(error);
        });
    }

    handleUpload(){
        alert('Google Drive Upload Coming Next Step 🚀');
    }
}