public class GoogleDriveUploadJob implements Queueable, Database.AllowsCallouts {

    private Id contentVersionId;
    private String uploadUrl;
    private String mimeType;
    private Integer offset;
    private Integer fileSize;
    private Id uploadStatusId;

    public GoogleDriveUploadJob(
        Id contentVersionId,
        String uploadUrl,
        String mimeType,
        Integer offset,
        Integer fileSize,
        Id uploadStatusId
    ) {
        this.contentVersionId = contentVersionId;
        this.uploadUrl        = uploadUrl;
        this.mimeType         = mimeType;
        this.offset           = offset;
        this.fileSize         = fileSize;
        this.uploadStatusId   = uploadStatusId;
    }

    public void execute(QueueableContext ctx) {
        System.debug('DriveUploadJob → offset: ' + offset + ' / ' + fileSize);

        // 4MB chunk size
        Integer chunkSize = 4 * 1024 * 1024;

        try {
            // Sirf VersionData query karo
            ContentVersion cvData = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            // Base64 encode karo aur chunk nikalo
            String  base64Full       = EncodingUtil.base64Encode(cvData.VersionData);
            Integer remaining        = fileSize - offset;
            Integer currentChunkSize = Math.min(chunkSize, remaining);

            // Base64 substring calculate karo
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

            System.debug('Uploading chunk: ' + contentRange + ' | size: ' + actualSize);

            // Chunk Google Drive pe upload karo
            HttpRequest req = new HttpRequest();
            req.setEndpoint(uploadUrl);
            req.setMethod('PUT');
            req.setHeader('Content-Type',  mimeType);
            req.setHeader('Content-Range', contentRange);
            req.setBodyAsBlob(chunkBlob);
            req.setTimeout(120000);

            HttpResponse res = new Http().send(req);
            System.debug('Chunk response: ' + res.getStatusCode());

            Integer nextOffset = offset + actualSize;

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                // Upload complete - file ID lo
                Map<String, Object> data =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String fileId    = (String) data.get('id');
                String driveLink = 'https://drive.google.com/file/d/' + fileId + '/view';

                // Status done update karo
                updateStatus(uploadStatusId, 'done', nextOffset, fileId, driveLink, null);
                System.debug('Upload COMPLETE → fileId: ' + fileId);

            } else if (res.getStatusCode() == 308) {
                // Chunk accepted - next chunk ke liye naya job queue karo
                updateStatus(uploadStatusId, 'inprogress', nextOffset, null, null, null);

                // Next chunk Queueable job mein
                System.enqueueJob(new GoogleDriveUploadJob(
                    contentVersionId,
                    uploadUrl,
                    mimeType,
                    nextOffset,
                    fileSize,
                    uploadStatusId
                ));
                System.debug('Next chunk queued → offset: ' + nextOffset);

            } else {
                // Upload fail
                String errMsg = 'Chunk failed [' + res.getStatusCode() + ']: ' + res.getBody();
                updateStatus(uploadStatusId, 'error', offset, null, null, errMsg);
                System.debug('Chunk FAILED → ' + errMsg);
            }

        } catch (Exception e) {
            System.debug('Job EXCEPTION: ' + e.getMessage());
            updateStatus(uploadStatusId, 'error', offset, null, null, e.getMessage());
        }
    }

    // Status record update karo
    private static void updateStatus(
        Id statusId,
        String status,
        Integer offset,
        String fileId,
        String driveLink,
        String errorMsg
    ) {
        GoogleDriveUploadStatus__c s = new GoogleDriveUploadStatus__c(
            Id          = statusId,
            Status__c   = status,
            Offset__c   = offset,
            File_Id__c  = fileId,
            Drive_Link__c = driveLink,
            Error__c    = errorMsg
        );
        update s;
        System.debug('Status updated → ' + status + ' | offset: ' + offset);
    }
}
