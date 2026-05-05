public without sharing class GoogleDriveCallbackController {

    public String message { get; set; }

    public PageReference handleCallback() {
        String code  = ApexPages.currentPage().getParameters().get('code');
        String error = ApexPages.currentPage().getParameters().get('error');

        System.debug('handleCallback → code present: ' + String.isNotBlank(code) + ' | error: ' + error);

        if (String.isNotBlank(error)) {
            message = 'Error: ' + error;
            return null;
        }

        if (String.isNotBlank(code)) {
            try {
                GoogleDriveAuthController.exchangeCodeForToken(code);
                message = 'success';
                System.debug('handleCallback → SUCCESS');
            } catch (Exception e) {
                message = 'Error: ' + e.getMessage();
                System.debug('handleCallback EXCEPTION → ' + e.getMessage());
            }
        }
        return null;
    }
}