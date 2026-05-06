// public with sharing class GoogleDriveUploadController {

//     @AuraEnabled
//     public static List<Map<String, String>> uploadFilesToDrive(
//         List<Id> contentVersionIds,
//         String folderId
//     ) {
//         System.debug('uploadFilesToDrive → files: ' + contentVersionIds.size());

//         String accessToken = GoogleDriveAuthController.getValidAccessToken();
//         List<Map<String, String>> results = new List<Map<String, String>>();

//         // FIX: Ek saath saari files query mat karo (heap limit)
//         // Har file ko alag alag query karo
//         for (Id cvId : contentVersionIds) {

//             // Ek file at a time query karo - VersionData LOB field hai
//             List<ContentVersion> cvList = [
//                 SELECT Id, Title, VersionData, FileType, ContentSize
//                 FROM ContentVersion
//                 WHERE Id = :cvId
//                 LIMIT 1
//             ];

//             Map<String, String> result = new Map<String, String>();

//             if (cvList.isEmpty()) {
//                 result.put('fileName', cvId);
//                 result.put('status',   'error');
//                 result.put('error',    'ContentVersion not found');
//                 results.add(result);
//                 continue;
//             }

//             ContentVersion cv = cvList[0];
//             result.put('fileName', cv.Title);

//             try {
//                 String fileId = uploadSingleFile(cv, accessToken, folderId);
//                 result.put('status',      'success');
//                 result.put('driveFileId', fileId);
//                 result.put('driveLink',   'https://drive.google.com/file/d/' + fileId + '/view');
//                 System.debug('Upload SUCCESS → ' + cv.Title + ' | fileId: ' + fileId);
//             } catch (Exception e) {
//                 result.put('status', 'error');
//                 result.put('error',  e.getMessage());
//                 System.debug('Upload FAILED → ' + cv.Title + ' | ' + e.getMessage());
//             }

//             results.add(result);
//         }

//         return results;
//     }

//     // Single file Google Drive pe upload karta hai (resumable upload)
//     private static String uploadSingleFile(
//         ContentVersion cv,
//         String accessToken,
//         String folderId
//     ) {
//         String mimeType = getMimeType(cv.FileType);

//         // File metadata banao
//         Map<String, Object> metadata = new Map<String, Object>();
//         metadata.put('name', cv.Title);
//         if (String.isNotBlank(folderId)) {
//             metadata.put('parents', new List<String>{ folderId });
//         }

//         // Step 1: Resumable upload session start karo
//         HttpRequest initReq = new HttpRequest();
//         initReq.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable');
//         initReq.setMethod('POST');
//         initReq.setHeader('Authorization',           'Bearer ' + accessToken);
//         initReq.setHeader('Content-Type',            'application/json; charset=UTF-8');
//         initReq.setHeader('X-Upload-Content-Type',   mimeType);
//         initReq.setHeader('X-Upload-Content-Length', String.valueOf(cv.ContentSize));
//         initReq.setBody(JSON.serialize(metadata));

//         HttpResponse initRes = new Http().send(initReq);
//         System.debug('Initiate upload → status: ' + initRes.getStatusCode());

//         if (initRes.getStatusCode() != 200) {
//             throw new AuraHandledException('Init failed: ' + initRes.getBody());
//         }

//         String uploadUrl = initRes.getHeader('Location');
//         if (String.isBlank(uploadUrl)) {
//             throw new AuraHandledException('No upload URL from Google.');
//         }

//         // Step 2: File bytes upload karo
//         HttpRequest uploadReq = new HttpRequest();
//         uploadReq.setEndpoint(uploadUrl);
//         uploadReq.setMethod('PUT');
//         uploadReq.setHeader('Content-Type', mimeType);
//         uploadReq.setBodyAsBlob(cv.VersionData);
//         uploadReq.setTimeout(120000);

//         HttpResponse uploadRes = new Http().send(uploadReq);
//         System.debug('File upload → status: ' + uploadRes.getStatusCode());

//         if (uploadRes.getStatusCode() == 200 || uploadRes.getStatusCode() == 201) {
//             Map<String, Object> response =
//                 (Map<String, Object>) JSON.deserializeUntyped(uploadRes.getBody());
//             return (String) response.get('id');
//         } else {
//             throw new AuraHandledException('Upload failed: ' + uploadRes.getBody());
//         }
//     }

//     private static String getMimeType(String fileType) {
//         Map<String, String> mimeMap = new Map<String, String>{
//             'PDF'  => 'application/pdf',
//             'PNG'  => 'image/png',
//             'JPG'  => 'image/jpeg',
//             'JPEG' => 'image/jpeg',
//             'GIF'  => 'image/gif',
//             'DOCX' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
//             'DOC'  => 'application/msword',
//             'XLSX' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
//             'XLS'  => 'application/vnd.ms-excel',
//             'PPTX' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
//             'CSV'  => 'text/csv',
//             'TXT'  => 'text/plain',
//             'ZIP'  => 'application/zip',
//             'MP4'  => 'video/mp4',
//             'MP3'  => 'audio/mpeg',
//             'SVG'  => 'image/svg+xml',
//             'WEBP' => 'image/webp'
//         };
//         return mimeMap.containsKey(fileType?.toUpperCase())
//             ? mimeMap.get(fileType.toUpperCase())
//             : 'application/octet-stream';
//     }
// }




public with sharing class GoogleDriveUploadController {

    // Small files ke liye seedha upload - ek hi Apex call
    @AuraEnabled
    public static Map<String, String> uploadSmallFile(
        Id contentVersionId,
        String folderId
    ) {
        System.debug('uploadSmallFile → ' + contentVersionId);

        // Token pehle lo - koi DML nahi hoga agar already valid hai
        // Agar refresh hua toh @future se update hoga - callout se conflict nahi
        String accessToken = GoogleDriveAuthController.getValidAccessToken();

        // Metadata alag query - VersionData baad mein
        ContentVersion meta = [
            SELECT Id, Title, FileType, ContentSize
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        // VersionData alag query - heap safe
        ContentVersion cvData = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        String mimeType  = getMimeType(meta.FileType);

        // Step 1: Resumable session initiate karo
        String uploadUrl = initiateSession(
            meta.Title, meta.ContentSize, mimeType, accessToken, folderId
        );

        // Step 2: File upload karo
        HttpRequest req = new HttpRequest();
        req.setEndpoint(uploadUrl);
        req.setMethod('PUT');
        req.setHeader('Content-Type', mimeType);
        req.setBodyAsBlob(cvData.VersionData);
        req.setTimeout(120000);

        HttpResponse res = new Http().send(req);
        System.debug('Small upload response: ' + res.getStatusCode());

        Map<String, String> result = new Map<String, String>();
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> data =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String fileId = (String) data.get('id');
            result.put('status',    'success');
            result.put('fileId',    fileId);
            result.put('driveLink', 'https://drive.google.com/file/d/' + fileId + '/view');
            System.debug('Small upload SUCCESS → fileId: ' + fileId);
        } else {
            result.put('status', 'error');
            result.put('error',
                'Upload failed [' + res.getStatusCode() + ']: ' + res.getBody()
            );
            System.debug('Small upload FAILED → ' + res.getBody());
        }
        return result;
    }

    // Large files ke liye Step 1: Resumable session initiate karo
    // Session URL LWC ko return hota hai
    @AuraEnabled
    public static String initiateLargeUpload(
        Id contentVersionId,
        String folderId
    ) {
        System.debug('initiateLargeUpload → ' + contentVersionId);

        String accessToken = GoogleDriveAuthController.getValidAccessToken();

        ContentVersion meta = [
            SELECT Id, Title, FileType, ContentSize
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        String mimeType  = getMimeType(meta.FileType);
        String uploadUrl = initiateSession(
            meta.Title, meta.ContentSize, mimeType, accessToken, folderId
        );

        System.debug('Session ready for: ' + meta.Title + ' | size: ' + meta.ContentSize);

        // uploadUrl|||fileSize|||mimeType format mein return karo
        return uploadUrl + '|||' + meta.ContentSize + '|||' + mimeType;
    }

    // Large files ke liye Step 2: Ek chunk upload karo
    // LWC baar baar ye call karta hai jab tak file complete na ho
    @AuraEnabled
    public static Map<String, String> uploadChunk(
        Id contentVersionId,
        String uploadUrl,
        String mimeType,
        Integer offset,
        Integer fileSize
    ) {
        System.debug('uploadChunk → offset: ' + offset + ' / ' + fileSize);

        Integer chunkSize = 4 * 1024 * 1024; // 4MB per chunk

        // Sirf VersionData query karo
        ContentVersion cvData = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        // Base64 se chunk nikalo
        String  base64Full       = EncodingUtil.base64Encode(cvData.VersionData);
        Integer remaining        = fileSize - offset;
        Integer currentChunkSize = Math.min(chunkSize, remaining);

        // Base64 substring calculate karo
        // 3 bytes = 4 base64 chars
        Integer b64Start = (offset / 3) * 4;
        Integer b64End   = Math.min(
            ((offset + currentChunkSize + 2) / 3) * 4,
            base64Full.length()
        );

        String b64Chunk = base64Full.substring(b64Start, b64End);

        // Base64 padding fix karo
        Integer padMod = Math.mod(b64Chunk.length(), 4);
        if      (padMod == 2) b64Chunk += '==';
        else if (padMod == 3) b64Chunk += '=';

        Blob    chunkBlob    = EncodingUtil.base64Decode(b64Chunk);
        Integer actualSize   = chunkBlob.size();
        Integer chunkEnd     = offset + actualSize - 1;
        String  contentRange = 'bytes ' + offset + '-' + chunkEnd + '/' + fileSize;

        System.debug('Sending chunk: ' + contentRange + ' | blob size: ' + actualSize);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(uploadUrl);
        req.setMethod('PUT');
        req.setHeader('Content-Type',  mimeType);
        req.setHeader('Content-Range', contentRange);
        req.setBodyAsBlob(chunkBlob);
        req.setTimeout(120000);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             

        HttpResponse res = new Http().send(req);
        System.debug('Chunk response: ' + res.getStatusCode());

        Map<String, String> result = new Map<String, String>();

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            // Upload complete - file ID lo
            Map<String, Object> data =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String fileId = (String) data.get('id');
            result.put('status',     'done');
            result.put('fileId',     fileId);
            result.put('driveLink',  'https://drive.google.com/file/d/' + fileId + '/view');
            result.put('nextOffset', String.valueOf(fileSize));
            System.debug('Chunk upload DONE → fileId: ' + fileId);

        } else if (res.getStatusCode() == 308) {
            // Chunk accepted - next chunk bhejo
            result.put('status',     'continue');
            result.put('nextOffset', String.valueOf(offset + actualSize));
            System.debug('Chunk accepted (308) → next offset: ' + (offset + actualSize));

        } else {
            result.put('status', 'error');
            result.put('error',
                'Chunk failed [' + res.getStatusCode() + ']: ' + res.getBody()
            );
            System.debug('Chunk FAILED → ' + res.getBody());
        }

        return result;
    }

    // Backward compatibility ke liye - purana method
    @AuraEnabled
    public static List<Map<String, String>> uploadFilesToDrive(
        List<Id> contentVersionIds,
        String folderId
    ) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Id cvId : contentVersionIds) {
            try {
                Map<String, String> r = uploadSmallFile(cvId, folderId);
                results.add(r);
            } catch(Exception e) {
                Map<String, String> r = new Map<String, String>();
                r.put('status', 'error');
                r.put('error',  e.getMessage());
                results.add(r);
            }
        }
        return results;
    }

    // Google Drive resumable upload session initiate karta hai
    private static String initiateSession(
        String fileName,
        Integer fileSize,
        String mimeType,
        String accessToken,
        String folderId
    ) {
        Map<String, Object> metadata = new Map<String, Object>();
        metadata.put('name', fileName);
        if (String.isNotBlank(folderId)) {
            metadata.put('parents', new List<String>{ folderId });
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable'
        );
        req.setMethod('POST');
        req.setHeader('Authorization',           'Bearer ' + accessToken);
        req.setHeader('Content-Type',            'application/json; charset=UTF-8');
        req.setHeader('X-Upload-Content-Type',   mimeType);
        req.setHeader('X-Upload-Content-Length', String.valueOf(fileSize));
        req.setBody(JSON.serialize(metadata));

        HttpResponse res = new Http().send(req);
        System.debug('initiateSession → status: ' + res.getStatusCode());

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Session init failed: ' + res.getBody());
        }

        String url = res.getHeader('Location');
        if (String.isBlank(url)) {
            throw new AuraHandledException('No upload URL returned.');
        }
        return url;
    }

    // File extension se MIME type determine karta hai
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
