public with sharing class GoogleDriveUploadController {

    @AuraEnabled
    public static List<Map<String, String>> uploadFilesToDrive(
        List<Id> contentVersionIds,   // ✅ FIXED (String → Id)
        String folderId
    ) {
        System.debug('uploadFilesToDrive → files: ' + contentVersionIds.size());

        String accessToken = GoogleDriveAuthController.getValidAccessToken();
        List<Map<String, String>> results = new List<Map<String, String>>();

        List<ContentVersion> cvList = [
            SELECT Id, Title, VersionData, FileType, ContentSize
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ];

        for (ContentVersion cv : cvList) {

            Map<String, String> result = new Map<String, String>();
            result.put('fileName', cv.Title);

            try {
                String fileId = uploadSingleFile(cv, accessToken, folderId);

                result.put('status', 'success');
                result.put('driveFileId', fileId);
                result.put('driveLink', 'https://drive.google.com/file/d/' + fileId + '/view');

            } catch (Exception e) {
                result.put('status', 'error');
                result.put('error', e.getMessage());
            }

            results.add(result);
        }

        return results;
    }

    private static String uploadSingleFile(ContentVersion cv, String accessToken, String folderId) {

        String mimeType = getMimeType(cv.FileType);

        Map<String, Object> metadata = new Map<String, Object>();
        metadata.put('name', cv.Title);
        if (String.isNotBlank(folderId)) {
            metadata.put('parents', new List<String>{ folderId });
        }

        // Step 1: Start upload session
        HttpRequest initReq = new HttpRequest();
        initReq.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable');
        initReq.setMethod('POST');
        initReq.setHeader('Authorization', 'Bearer ' + accessToken);
        initReq.setHeader('Content-Type', 'application/json; charset=UTF-8');
        initReq.setHeader('X-Upload-Content-Type', mimeType);
        initReq.setHeader('X-Upload-Content-Length', String.valueOf(cv.ContentSize));
        initReq.setBody(JSON.serialize(metadata));

        HttpResponse initRes = new Http().send(initReq);

        if (initRes.getStatusCode() != 200) {
            throw new AuraHandledException('Init failed: ' + initRes.getBody());
        }

        String uploadUrl = initRes.getHeader('Location');

        // Step 2: Upload file
        HttpRequest uploadReq = new HttpRequest();
        uploadReq.setEndpoint(uploadUrl);
        uploadReq.setMethod('PUT');
        uploadReq.setHeader('Content-Type', mimeType);
        uploadReq.setBodyAsBlob(cv.VersionData);

        HttpResponse uploadRes = new Http().send(uploadReq);

        if (uploadRes.getStatusCode() == 200 || uploadRes.getStatusCode() == 201) {
            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(uploadRes.getBody());
            return (String) response.get('id');
        } else {
            throw new AuraHandledException('Upload failed: ' + uploadRes.getBody());
        }
    }

    private static String getMimeType(String fileType) {
        Map<String, String> mimeMap = new Map<String, String>{
            'PDF' => 'application/pdf',
            'PNG' => 'image/png',
            'JPG' => 'image/jpeg',
            'DOCX' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        };

        return mimeMap.containsKey(fileType?.toUpperCase())
            ? mimeMap.get(fileType.toUpperCase())
            : 'application/octet-stream';
    }
}