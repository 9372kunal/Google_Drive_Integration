// public with sharing class GoogleDriveAuthController {

//     private static GoogleDriveConfig__c config {
//         get {
//             if (config == null) config = GoogleDriveConfig__c.getInstance();
//             return config;
//         }
//         set;
//     }

//     @AuraEnabled
//     public static String getAuthUrl() {
//         String clientId    = config.Client_Id__c;
//         String redirectUri = EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
//         String scope       = EncodingUtil.urlEncode('https://www.googleapis.com/auth/drive.file email profile openid', 'UTF-8');
//         String state       = EncodingUtil.urlEncode(UserInfo.getUserId(), 'UTF-8');

//         String authUrl = 'https://accounts.google.com/o/oauth2/v2/auth'
//             + '?client_id='    + clientId
//             + '&redirect_uri=' + redirectUri
//             + '&response_type=code'
//             + '&scope='        + scope
//             + '&access_type=offline'
//             + '&prompt=consent'
//             + '&state='        + state;

//         System.debug('getAuthUrl → URL generated successfully');
//         return authUrl;
//     }

//     @AuraEnabled
//     public static void exchangeCodeForToken(String code) {
//         System.debug('exchangeCodeForToken → called');

//         HttpRequest req = new HttpRequest();
//         req.setEndpoint('https://oauth2.googleapis.com/token');
//         req.setMethod('POST');
//         req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
//         req.setBody(
//               'code='           + EncodingUtil.urlEncode(code, 'UTF-8')
//             + '&client_id='     + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
//             + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
//             + '&redirect_uri='  + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8')
//             + '&grant_type=authorization_code'
//         );

//         HttpResponse res = new Http().send(req);
//         System.debug('exchangeCodeForToken → status: ' + res.getStatusCode());

//         if (res.getStatusCode() == 200) {
//             Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
//             saveToken(tokenData);
//         } else {
//             System.debug('exchangeCodeForToken FAILED → ' + res.getBody());
//             throw new AuraHandledException('Token exchange failed: ' + res.getBody());
//         }
//     }

//     private static void saveToken(Map<String, Object> tokenData) {
//         String userId      = UserInfo.getUserId();
//         String accessToken = (String) tokenData.get('access_token');
//         String googleEmail = fetchGoogleEmail(accessToken);

//         GoogleDriveToken__c token = getExistingToken(userId);
//         if (token == null) token  = new GoogleDriveToken__c(User__c = userId);

//         token.Access_Token__c = accessToken;
//         token.Google_Email__c = googleEmail;
//         token.Token_Expiry__c = DateTime.now().addSeconds((Integer) tokenData.get('expires_in'));

//         if (tokenData.containsKey('refresh_token') && tokenData.get('refresh_token') != null) {
//             token.Refresh_Token__c = (String) tokenData.get('refresh_token');
//         }

//         upsert token;
//         System.debug('saveToken → token saved for: ' + googleEmail);
//     }

//     private static String fetchGoogleEmail(String accessToken) {
//         HttpRequest req = new HttpRequest();
//         req.setEndpoint('https://www.googleapis.com/oauth2/v2/userinfo');
//         req.setMethod('GET');
//         req.setHeader('Authorization', 'Bearer ' + accessToken);
//         HttpResponse res = new Http().send(req);

//         if (res.getStatusCode() == 200) {
//             Map<String, Object> info = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
//             return (String) info.get('email');
//         }
//         System.debug('fetchGoogleEmail FAILED → status: ' + res.getStatusCode());
//         return '';
//     }

//     @AuraEnabled(cacheable=true)
//     public static Map<String, Object> getConnectionStatus() {
//         GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());
//         Boolean isConnected = token != null && String.isNotBlank(token.Refresh_Token__c);
//         System.debug('getConnectionStatus → isConnected: ' + isConnected);

//         Map<String, Object> result = new Map<String, Object>();
//         result.put('isConnected', isConnected);
//         result.put('googleEmail', token != null ? token.Google_Email__c : '');
//         return result;
//     }

//     @AuraEnabled
//     public static void disconnect() {
//         GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());
//         if (token != null) {
//             delete token;
//             System.debug('disconnect → token deleted');
//         }
//     }

//     public static String getValidAccessToken() {
//         GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());

//         if (token == null || String.isBlank(token.Refresh_Token__c)) {
//             throw new AuraHandledException('Google Drive not connected. Please connect your account first.');
//         }

//         if (token.Token_Expiry__c <= DateTime.now().addMinutes(5)) {
//             System.debug('getValidAccessToken → token expired, refreshing...');
//             token = refreshAccessToken(token);
//         }

//         return token.Access_Token__c;
//     }

//     private static GoogleDriveToken__c refreshAccessToken(GoogleDriveToken__c token) {
//         HttpRequest req = new HttpRequest();
//         req.setEndpoint('https://oauth2.googleapis.com/token');
//         req.setMethod('POST');
//         req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
//         req.setBody(
//               'client_id='     + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
//             + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
//             + '&refresh_token=' + EncodingUtil.urlEncode(token.Refresh_Token__c, 'UTF-8')
//             + '&grant_type=refresh_token'
//         );

//         HttpResponse res = new Http().send(req);
//         System.debug('refreshAccessToken → status: ' + res.getStatusCode());

//         if (res.getStatusCode() == 200) {
//             Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
//             token.Access_Token__c    = (String) data.get('access_token');
//             token.Token_Expiry__c    = DateTime.now().addSeconds((Integer) data.get('expires_in'));
//             update token;
//         } else {
//             System.debug('refreshAccessToken FAILED → ' + res.getBody());
//             throw new AuraHandledException('Token refresh failed: ' + res.getBody());
//         }

//         return token;
//     }

//     private static GoogleDriveToken__c getExistingToken(String userId) {
//         List<GoogleDriveToken__c> tokens = [
//             SELECT Id, Access_Token__c, Refresh_Token__c, Token_Expiry__c, Google_Email__c
//             FROM GoogleDriveToken__c
//             WHERE User__c = :userId
//             LIMIT 1
//         ];
//         return tokens.isEmpty() ? null : tokens[0];
//     }
// }


public with sharing class GoogleDriveAuthController {

    // Custom Setting se config lazily load karta hai (Client Id, Secret, Redirect URI)
    private static GoogleDriveConfig__c config {
        get {
            if (config == null) config = GoogleDriveConfig__c.getInstance();
            return config;
        }
        set;
    }

    // Google OAuth authorization URL banata hai
    // LWC is URL ko popup mein open karta hai
    @AuraEnabled
    public static String getAuthUrl() {
        String clientId    = config.Client_Id__c;
        String redirectUri = EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
        String scope       = EncodingUtil.urlEncode(
            'https://www.googleapis.com/auth/drive.file email profile openid', 'UTF-8'
        );
        String state = EncodingUtil.urlEncode(UserInfo.getUserId(), 'UTF-8');

        String authUrl = 'https://accounts.google.com/o/oauth2/v2/auth'
            + '?client_id='    + clientId
            + '&redirect_uri=' + redirectUri
            + '&response_type=code'
            + '&scope='        + scope
            + '&access_type=offline'
            + '&prompt=consent'
            + '&state='        + state;

        System.debug('getAuthUrl → URL generated successfully');
        return authUrl;
    }

    // Google se mila authorization code access token se exchange karta hai
    @AuraEnabled
    public static void exchangeCodeForToken(String code) {
        System.debug('exchangeCodeForToken → called');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(
              'code='           + EncodingUtil.urlEncode(code, 'UTF-8')
            + '&client_id='     + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
            + '&redirect_uri='  + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8')
            + '&grant_type=authorization_code'
        );

        HttpResponse res = new Http().send(req);
        System.debug('exchangeCodeForToken → status: ' + res.getStatusCode());

        if (res.getStatusCode() == 200) {
            Map<String, Object> tokenData =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            saveToken(tokenData);
        } else {
            System.debug('exchangeCodeForToken FAILED → ' + res.getBody());
            throw new AuraHandledException('Token exchange failed: ' + res.getBody());
        }
    }

    // Token data Salesforce mein save karta hai
    // Callout pehle ho chuka hai (fetchGoogleEmail), DML baad mein - sahi order
    private static void saveToken(Map<String, Object> tokenData) {
        String userId      = UserInfo.getUserId();
        String accessToken = (String) tokenData.get('access_token');

        // Google se email fetch karo (ye callout hai)
        String googleEmail = fetchGoogleEmail(accessToken);

        // Callout ke baad DML - allowed hai
        GoogleDriveToken__c token = getExistingToken(userId);
        if (token == null) token  = new GoogleDriveToken__c(User__c = userId);

        token.Access_Token__c = accessToken;
        token.Google_Email__c = googleEmail;
        token.Token_Expiry__c = DateTime.now().addSeconds(
            (Integer) tokenData.get('expires_in')
        );

        // Refresh token sirf pehli baar milta hai
        if (tokenData.containsKey('refresh_token') && tokenData.get('refresh_token') != null) {
            token.Refresh_Token__c = (String) tokenData.get('refresh_token');
        }

        upsert token;
        System.debug('saveToken → token saved for: ' + googleEmail);
    }

    // Access token use karke Google se user ka email fetch karta hai
    private static String fetchGoogleEmail(String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.googleapis.com/oauth2/v2/userinfo');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> info =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) info.get('email');
        }
        System.debug('fetchGoogleEmail FAILED → status: ' + res.getStatusCode());
        return '';
    }

    // Current user ka Google Drive connection status return karta hai
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConnectionStatus() {
        GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());
        Boolean isConnected = token != null && String.isNotBlank(token.Refresh_Token__c);
        System.debug('getConnectionStatus → isConnected: ' + isConnected);

        Map<String, Object> result = new Map<String, Object>();
        result.put('isConnected', isConnected);
        result.put('googleEmail', token != null ? token.Google_Email__c : '');
        return result;
    }

    // Current user ka Google Drive token delete karta hai
    @AuraEnabled
    public static void disconnect() {
        GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());
        if (token != null) {
            delete token;
            System.debug('disconnect → token deleted');
        }
    }

    // Upload se pehle LWC ye call karta hai
    // Agar token expire ho toh refresh + DML yahan hoga
    // Upload callout alag transaction mein hoga - conflict nahi
    @AuraEnabled
    public static void ensureTokenFresh() {
        System.debug('ensureTokenFresh → called');
        GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());

        if (token == null || String.isBlank(token.Refresh_Token__c)) {
            throw new AuraHandledException('Google Drive not connected.');
        }

        // Token 5 minute mein expire hone wala hai toh refresh karo
        if (token.Token_Expiry__c <= DateTime.now().addMinutes(5)) {
            System.debug('ensureTokenFresh → token needs refresh');
            refreshAndSaveToken(token);
        } else {
            System.debug('ensureTokenFresh → token is valid, no refresh needed');
        }
    }

    // Token refresh karo aur seedha save karo
    // Callout pehle → DML baad mein → sahi order, koi conflict nahi
    private static void refreshAndSaveToken(GoogleDriveToken__c token) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(
              'client_id='      + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
            + '&refresh_token=' + EncodingUtil.urlEncode(token.Refresh_Token__c, 'UTF-8')
            + '&grant_type=refresh_token'
        );

        HttpResponse res = new Http().send(req);
        System.debug('refreshAndSaveToken → status: ' + res.getStatusCode());

        if (res.getStatusCode() == 200) {
            Map<String, Object> data =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            // Callout ke baad DML - sahi order
            token.Access_Token__c = (String) data.get('access_token');
            token.Token_Expiry__c = DateTime.now().addSeconds(
                (Integer) data.get('expires_in')
            );
            update token;
            System.debug('refreshAndSaveToken → token updated successfully');
        } else {
            System.debug('refreshAndSaveToken FAILED → ' + res.getBody());
            throw new AuraHandledException('Token refresh failed: ' + res.getBody());
        }
    }

    // Valid access token return karta hai - koi DML nahi karta
    // ensureTokenFresh() pehle LWC se call hona chahiye
    public static String getValidAccessToken() {
        GoogleDriveToken__c token = getExistingToken(UserInfo.getUserId());

        if (token == null || String.isBlank(token.Refresh_Token__c)) {
            throw new AuraHandledException(
                'Google Drive not connected. Please connect your account first.'
            );
        }

        System.debug('getValidAccessToken → returning existing token');
        return token.Access_Token__c;
    }

    // Database se current user ka token record fetch karta hai
    private static GoogleDriveToken__c getExistingToken(String userId) {
        List<GoogleDriveToken__c> tokens = [
            SELECT Id, Access_Token__c, Refresh_Token__c, Token_Expiry__c, Google_Email__c
            FROM GoogleDriveToken__c
            WHERE User__c = :userId
            LIMIT 1
        ];
        return tokens.isEmpty() ? null : tokens[0];
    }
}