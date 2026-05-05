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
            return result;
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

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>();

        for(ContentVersion cv : [
            SELECT Id, Title, FileType, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
        ]){
            cvMap.put(cv.ContentDocumentId, cv);
        }

        Integer i = 1;

        for(ContentDocumentLink link : links){

            ContentVersion cv = cvMap.get(link.ContentDocumentId);

            if(cv != null){
                result.add(new FileWrapper(
                    i++,
                    recordMap.get(link.LinkedEntityId),
                    link.ContentDocumentId,
                    cv.Id,
                    cv.Title,
                    cv.FileType
                ));
            }
        }

        return result;
    }

    public class FileWrapper {
        @AuraEnabled public Integer sno;
        @AuraEnabled public String recordName;
        @AuraEnabled public Id fileId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String fileName;
        @AuraEnabled public String fileType;

        public FileWrapper(Integer sno, String recordName, Id fileId, Id contentVersionId, String fileName, String fileType){
            this.sno = sno;
            this.recordName = recordName;
            this.fileId = fileId;
            this.contentVersionId = contentVersionId;
            this.fileName = fileName;
            this.fileType = fileType;
        }
    }
}