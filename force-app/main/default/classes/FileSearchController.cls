public with sharing class FileSearchController {

    @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {
        return new List<String>{
         'Account','Contact','Lead','Opportunity','Case'
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getRecordsWithFiles(String objectName) {

        List<FileWrapper> result = new List<FileWrapper>();

        if(String.isBlank(objectName)){
            return result;a
        }

        String query = 'SELECT Id, Name FROM ' + objectName + ' LIMIT 100';
        List<SObject> records = Database.query(query);

        if(records.isEmpty()){
            return result;
        }

        Map<Id, String> recordMap = new Map<Id, String>();
        Set<Id> recordIds = new Set<Id>();

        for(SObject rec : records){
            recordIds.add(rec.Id);
            recordMap.put(rec.Id, (String)rec.get('Name'));
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
        ];

        if(links.isEmpty()){
            return result;
        }

        Set<Id> docIds = new Set<Id>();
        for(ContentDocumentLink l : links){
            docIds.add(l.ContentDocumentId);
        }

        Map<Id, String> fileTypeMap = new Map<Id, String>();
        Map<Id, String> fileNameMap = new Map<Id, String>();

        for(ContentVersion cv : [
            SELECT ContentDocumentId, FileExtension, Title
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
        ]){
            fileTypeMap.put(cv.ContentDocumentId, cv.FileExtension);
            fileNameMap.put(cv.ContentDocumentId, cv.Title);
        }

        for(Integer i = 0; i < links.size(); i++){

            ContentDocumentLink link = links[i];

            String type = fileTypeMap.get(link.ContentDocumentId);
            String name = fileNameMap.get(link.ContentDocumentId);

            if(String.isBlank(type)) type = 'Unknown';
            if(String.isBlank(name)) name = 'No Name';

            result.add(new FileWrapper(
                i + 1,
                recordMap.get(link.LinkedEntityId),
                link.ContentDocumentId,
                type,
                name
            ));
        }

        return result;
    }

    public class FileWrapper {
        @AuraEnabled public Integer sno;
        @AuraEnabled public String recordName;
        @AuraEnabled public Id fileId;
        @AuraEnabled public String fileType;
        @AuraEnabled public String fileName;

        public FileWrapper(Integer sno, String recordName, Id fileId, String fileType, String fileName){
            this.sno = sno;
            this.recordName = recordName;
            this.fileId = fileId;
            this.fileType = fileType;
            this.fileName = fileName;
        }
    }
}