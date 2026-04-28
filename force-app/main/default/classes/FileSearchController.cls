public with sharing class FileSearchController {
   @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getRecordsWithFiles(String objectName) {

        String query = 'SELECT Id FROM ' + objectName + ' LIMIT 100';
        List<SObject> records = Database.query(query);

        Set<Id> recordIds = new Set<Id>();
        for(SObject rec : records){
            recordIds.add(rec.Id);
        }

        if(recordIds.isEmpty()){
            return new List<FileWrapper>();
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
        ];

        if(links.isEmpty()){
            return new List<FileWrapper>();
        }

        List<FileWrapper> result = new List<FileWrapper>();
        Integer count = 1;

        for(ContentDocumentLink link : links){
            result.add(new FileWrapper(
                count,
                link.LinkedEntityId,
                link.ContentDocumentId,
                'File'
            ));
            count++;
        }

        return result;
    }

    // 🔥 NEW METHOD → Get ALL Standard Objects
    @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
        List<String> objectNames = new List<String>();

        for(String objName : globalMap.keySet()){
            Schema.DescribeSObjectResult desciptionn = globalMap.get(objName).getDescribe();

            // Only Standard Objects
            if(!desciptionn.isCustom() && desciptionn.isQueryable()){
                objectNames.add(objName);
            }
        }

        objectNames.sort();
        return objectNames;
    }

    public class FileWrapper {
        @AuraEnabled public Integer sno;
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id fileId;
        @AuraEnabled public String fileType;

        public FileWrapper(Integer sno, Id recordId, Id fileId, String fileType){
            this.sno = sno;
            this.recordId = recordId;
            this.fileId = fileId;
            this.fileType = fileType;
        }
    }
}