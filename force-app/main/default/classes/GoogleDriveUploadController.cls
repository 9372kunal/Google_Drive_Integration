public with sharing class GoogleDriveUploadController {

    @AuraEnabled
    public static List<Map<String, String>> uploadFilesToDrive(
        List<Id> contentVersionIds,
        String folderId
    ) {
        System.debug('uploadFilesToDrive → files: ' + contentVersionIds.size());

        String accessToken = GoogleDriveAuthController.getValidAccessToken();
        List<Map<String, String>> results = new List<Map<String, String>>();

        // FIX: Ek saath saari files query mat karo (heap limit)
        // Har file ko alag alag query karo
        for (Id cvId : contentVersionIds) {

            // Ek file at a time query karo - VersionData LOB field hai
            List<ContentVersion> cvList = [
                SELECT Id, Title, VersionData, FileType, ContentSize
                FROM ContentVersion
                WHERE Id = :cvId
                LIMIT 1
            ];

            Map<String, String> result = new Map<String, String>();

            if (cvList.isEmpty()) {
                result.put('fileName', cvId);
                result.put('status',   'error');
                result.put('error',    'ContentVersion not found');
                results.add(result);
                continue;
            }

            ContentVersion cv = cvList[0];
            result.put('fileName', cv.Title);

            try {
                String fileId = uploadSingleFile(cv, accessToken, folderId);
                result.put('status',      'success');
                result.put('driveFileId', fileId);
                result.put('driveLink',   'https://drive.google.com/file/d/' + fileId + '/view');
                System.debug('Upload SUCCESS → ' + cv.Title + ' | fileId: ' + fileId);
            } catch (Exception e) {
                result.put('status', 'error');
                result.put('error',  e.getMessage());
                System.debug('Upload FAILED → ' + cv.Title + ' | ' + e.getMessage());
            }

            results.add(result);
        }

        return results;
    }

    // Single file Google Drive pe upload karta hai (resumable upload)
    private static String uploadSingleFile(
        ContentVersion cv,
        String accessToken,
        String folderId
    ) {
        String mimeType = getMimeType(cv.FileType);

        // File metadata banao
        Map<String, Object> metadata = new Map<String, Object>();
        metadata.put('name', cv.Title);
        if (String.isNotBlank(folderId)) {
            metadata.put('parents', new List<String>{ folderId });
        }

        // Step 1: Resumable upload session start karo
        HttpRequest initReq = new HttpRequest();
        initReq.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable');
        initReq.setMethod('POST');
        initReq.setHeader('Authorization',           'Bearer ' + accessToken);
        initReq.setHeader('Content-Type',            'application/json; charset=UTF-8');
        initReq.setHeader('X-Upload-Content-Type',   mimeType);
        initReq.setHeader('X-Upload-Content-Length', String.valueOf(cv.ContentSize));
        initReq.setBody(JSON.serialize(metadata));

        HttpResponse initRes = new Http().send(initReq);
        System.debug('Initiate upload → status: ' + initRes.getStatusCode());

        if (initRes.getStatusCode() != 200) {
            throw new AuraHandledException('Init failed: ' + initRes.getBody());
        }

        String uploadUrl = initRes.getHeader('Location');
        if (String.isBlank(uploadUrl)) {
            throw new AuraHandledException('No upload URL from Google.');
        }

        // Step 2: File bytes upload karo
        HttpRequest uploadReq = new HttpRequest();
        uploadReq.setEndpoint(uploadUrl);
        uploadReq.setMethod('PUT');
        uploadReq.setHeader('Content-Type', mimeType);
        uploadReq.setBodyAsBlob(cv.VersionData);
        uploadReq.setTimeout(120000);

        HttpResponse uploadRes = new Http().send(uploadReq);
        System.debug('File upload → status: ' + uploadRes.getStatusCode());

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
            'PDF'  => 'application/pdf',
            'PNG'  => 'image/png',
            'JPG'  => 'image/jpeg',
            'JPEG' => 'image/jpeg',
            'GIF'  => 'image/gif',
            'DOCX' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'DOC'  => 'application/msword',
            'XLSX' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'XLS'  => 'application/vnd.ms-excel',
            'PPTX' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'CSV'  => 'text/csv',
            'TXT'  => 'text/plain',
            'ZIP'  => 'application/zip',
            'MP4'  => 'video/mp4',
            'MP3'  => 'audio/mpeg',
            'SVG'  => 'image/svg+xml',
            'WEBP' => 'image/webp'
        };
        return mimeMap.containsKey(fileType?.toUpperCase())
            ? mimeMap.get(fileType.toUpperCase())
            : 'application/octet-stream';
    }
}

