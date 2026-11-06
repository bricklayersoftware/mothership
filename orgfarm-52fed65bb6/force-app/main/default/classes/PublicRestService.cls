// https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub
// https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/<endpoint>.php
// client_pubnub -- GET |      |     |

// https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce.com/
// sebastianwolf2947.598f03371d7a@agentforce.com
// As1df1gh!

// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd org login web --alias storagevault941@agentforce.com
// C:\Users\LC2022\AppData\Local\sfdx\bin\sf.cmd org auth show-access-token -o storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd deploy metadata -m ApexClass:PublicRestService -o storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd project retrieve start -m ApexClass:PublicRestService -o storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd apex generate class --name FileHelper --output-dir force-app/main/default/classes

// sf org login web --alias storagevault941@agentforce.com
// sf project deploy start --source-dir force-app/main/default/classes/PublicRestService.cls --target-org mothershiporg
// sf project retrieve start -m ApexTrigger
// sf deploy metadata -m ApexTrigger:ClientJobTrigger
// cmd /k F:\__Binaries\sfdx\bin\sf deploy metadata -m ApexClass:PublicRestService -o storagevault941@agentforce.com
// sf org list

// curl -v -X POST --data-binary "@customers-100.csv" <tplmothership>/ow/upload.php?filename=customers-100.csv
// curl -v -T customers-100.csv <tplmothership>/ow/upload.php?filename=cust.csv

@RestResource(urlMapping='/*')
global without sharing class PublicRestService {

    public static string mothership = 'https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/';

    static {
        Logger.LogSys('starting PublicRestService');

        String baseUrl = Url.getOrgDomainUrl().toExternalForm();
        List<String> parts = baseUrl.split('\\.'); 
        mothership = 'https://' + parts[0].removeStartIgnoreCase('https://')+'.develop.my.salesforce-sites.com/services/apexrest/';
    }   

    public static string getSubpoint(RestRequest req) {
        String relativeUrl = req.requestURI; 
        
        List<String> pathSegments = relativeUrl.split('/');
        
        String subpoint = '';
        
        if ( ! pathSegments.isEmpty() && pathSegments.size() >= 3 ) {
            subpoint = pathSegments.get(2);
        }

        return subpoint;
    }

    public static string getEndpoint(RestRequest req) {
        String relativeUrl = req.requestURI; 
        
        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() && pathSegments.size() >= 4 ) {
            endpoint = pathSegments.get(3);
        }

        return endpoint;
    }


    static Map<string,string> GetRequestProfile() {
        Map<string,string> out = new Map<string,string>();
        
        Id profileId = UserInfo.getProfileId(); 

		Profile currentUserProfile = [SELECT Name FROM Profile WHERE Id = :profileId LIMIT 1];
		
        String profileName = currentUserProfile != null ? currentUserProfile.Name : 'NULL_PROFILE';
        
		UserInfo.getUserId();
        UserInfo.getName();
        UserInfo.getLanguage();
        UserInfo.getLocale();
        
        out.put('ProfileID', profileId);
        out.put('ProfileName', profileName);
        out.put('UserId', UserInfo.getUserId());
        out.put('Username', UserInfo.getName());
        out.put('Language', UserInfo.getLanguage());
        out.put('Locale', UserInfo.getLocale());
        
        return out;
    }
    
    static string parseResponse(Map<string, object> response, Map<string, string> headers) {
        Logger.LogSys('starting', 'parseResponse');

        String joinedKeys = String.join(new List<String>(response.keySet()), ', ');

        Logger.LogSys('response keys: '+joinedKeys, 'parseResponse');

        if ( ! response.containsKey('result') ) {
            Logger.LogSys('response does not contain key [result]', 'parseResponse');
            return null;
        }

        object value = response.get('result');

        Map<string, object> result = (Map<string, object>) value;

        joinedKeys = String.join(new List<String>(result.keySet()), ', ');

        Logger.LogSys('result keys: '+joinedKeys, 'parseResponse');

        if ( result.containsKey('headers') ) {
            Map<string, object> theaders = (Map<string, object>) result.get('headers');

            for ( string hkey : theaders.keySet() ) {
                string theader = String.valueOf(theaders.get(hkey));
                Logger.LogSys('header key=['+hkey+'] value=['+theader+']','processcdp');
                
                if ( hkey != 'Content-Length' ) {
                    headers.put(hkey, theader);
                }
            }
        }

        if ( result.containsKey('requesturl') ) {
            string requesturl= String.valueOf(result.get('requesturl'));
            Logger.LogSys('requesturl=['+requesturl+']','processcdp');
        }

        if ( result.containsKey('body') ) {
            string body = (string) result.get('body'); // convert from base64
            
            Blob decodedBlob = EncodingUtil.base64Decode(body);
            body = decodedBlob.toString();
            
            Logger.LogSys('body=['+body+']','processcdp');

            return body;
        }

        return null;
    }

    // client_pubnub.html
    public static void serve_ui(RestRequest req, RestResponse res, string htmlfname) {
        ContentVersion cv = FileHelper.GetContentVersion(htmlfname); //'admin.html');

        if ( cv == null ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('version data is empty for '+htmlfname);
            return;
        }

        res.addHeader('Content-Type', 'text/html; charset=utf-8');

        res.responseBody = cv.VersionData;
        return;
    }

    // assets
    public static void serve_asset(RestRequest req, RestResponse res, string fname) {

        Logger.LogSys('starting with fname='+fname, 'serve_asset');

        ContentVersion cv = FileHelper.GetContentVersion(fname);

        if ( cv != null ) {
            res.statusCode = 400;        
            res.responseBody = Blob.valueOf('requested file does not exist: '+fname);        
            return;            
        }

        Blob fileBlob = cv.VersionData;

        if ( fileblob.size() == 0 ) {
            res.statusCode = 500;        
            res.responseBody = Blob.valueOf('requested file is empty: '+fname);            
            return;
        }

        res.addHeader('Content-Type', 'application/octet-stream');
        res.addHeader('Content-Disposition', 'attachment; filename="' + cv.Title + '"');
        // res.addHeader('Content-Length', String.valueOf(fileblob.size())); // results in error: Header name "Content-Length" is not allowed.
        res.addHeader('Expires', '0');
        res.addHeader('Cache-Control', 'must-revalidate');

        res.responseBody = fileBlob;

        return;
    }

    // upload.php -- PUT requests
    @HttpPut
    global static void handleRawPut() {
        string pp = 'handleRawPut';

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String relativeUrl = req.requestURI; 
        
        Logger.LogSys(pp +'|' + 'PUT request: ' + relativeUrl);

        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }

        if ( endpoint.contains('&') ) {
            endpoint = endpoint.split('&')[0];
        }

        Logger.LogSys(pp +'|' + 'endpoint=' + endpoint);

        if ( endpoint.toLowerCase() != 'upload.php' ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: invalid endpoint ['+endpoint+'] -- all PUT requests must be sent to upload.php\r\n');
            return;
        }

        Map<string,string> kvp = Helper.KVPLCase(req.params);

        string filename = kvp.containsKey('filename') ? kvp.get('filename') : '';

        Logger.LogSys(pp +'|' + 'filename=' + filename);

        if ( String.isBlank(filename) ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: filename param is empty\r\n');
            return;
        }

        Blob fileBlob = req.requestBody;

        if (fileBlob == null || fileBlob.size() == 0) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: upload file is empty\r\n');
            return;
        }
        
        res.statusCode = 500;
		res.responseBody = Blob.valueOf('FATAL ERROR :: should not have reached here\r\n');
    }

    // upload.php
    // curl -v -ks -X POST https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/upload.php?filename=test.txt 
    // -H "Content-Type: application/octet-stream" 
    // --data-binary @"%temp%\owd\test.txt"
    @HttpPost
    global static void processPostRequest() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String relativeUrl = req.requestURI; 
        
        Logger.LogSys('POST request: ' + relativeUrl);

        List<String> pathSegments = relativeUrl.split('/');
        
        String endpoint = '';
        
        if ( ! pathSegments.isEmpty() ) {
            endpoint = pathSegments.get(pathSegments.size()-1);
        }
        
        if ( ( endpoint != 'upload.php' ) ) {
			res.statusCode = 400;
            res.responseBody = Blob.valueOf('endpoint not supported: '+endpoint+ '\r\n');
            return;
        }

        Map<string,string> kvp = Helper.KVPLCase(req.params);
        
        String filename = kvp.containsKey('filename') ? kvp.get('filename') : '';

        Blob fileBlob = req.requestBody;
                       
        if ( String.isBlank(filename)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: url param filename is required');
            return;
        }

        if (fileBlob == null ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: file body data is null');
            return;
        }

        if ( fileBlob.size() == 0 ) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('ERROR :: file body byte count is zero');
            return;
        }

        string t_filename = filename;

        Logger.PublishMsgLogger('upload.php', 'mothership', 'uploading file: '+t_filename, req);

        Id currentUserId = UserInfo.getUserId();

        try {

            List<ContentDocument> docsToDelete = [
                SELECT Id 
                FROM ContentDocument 
                WHERE Id IN (
                    SELECT ContentDocumentId 
                    FROM ContentVersion 
                    WHERE Title = :filename
                )
            ];
            
            if (!docsToDelete.isEmpty()) {
                delete docsToDelete;
            }    
        } catch (Exception ex) {
            
        }
        
        ContentVersion cv = new ContentVersion();
        cv.Title = filename;
        cv.PathOnClient = '/' + filename; 
        cv.VersionData = fileBlob;
        cv.IsMajorVersion = true;
        // cv.ContentLocation = 'C'; // 'C' indicates it's stored in Salesforce
        cv.IsMajorVersion = true;
        cv.SharingPrivacy = 'N'; 
        cv.FirstPublishLocationId = currentUserId; // Automatically links the file to the user

        insert cv;
        
        string msgstr = 'filesize='+String.valueOf(fileBlob.size())+'|'+'filename='+t_filename + '|'+'recordid='+String.valueOf(cv.Id);
        
        Logger.PublishMsgLogger('upload.php', 'mothership', msgstr, req);

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(msgstr+ '\r\n');
        
        return;
    }
    
    
    // ping.php, logmsg.php, relay.php, retrieve.php
    // GET: /services/apexrest/StorageVault/
	// curl -v -ks -G https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/tttt/asdfas/asdfasf/asdfasd?asdf=123
	// asdf=123|[/StorageVault/tttt/asdfas/asdfasf/asdfasd]
	// X-Custom-Header: YourCustomValue
    @HttpGet
    global static void processGetRequest() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
		String htmlString = '';

        String relativeUrl = req.requestURI; 
        String endpoint = '';
        String subpoint = '';

        try {
            endpoint = getEndpoint(req);
            subpoint = getSubpoint(req);

            Logger.LogSys('relativeUrl='+relativeUrl+'|endpoint='+endpoint+'|subpoint='+subpoint, 'processGetRequest');
                       
            if ( String.isBlank(endpoint) ) {
                endpoint = subpoint;
                Logger.LogSys('modified endpoint='+endpoint, 'processGetRequest');
            }

            if ( endpoint == 'client_pubnub' ) {
                serve_ui(req,res, endpoint + '.html');
                return;
            } else {
                res.responseBody = Blob.valueOf('requested endpoint not supported');
                res.statusCode = 400;
            }

        } catch (Exception e) {
            Logger.LogSysEx(e);
            
            String stackTrace = e.getStackTraceString(); 

            res.responseBody = Blob.valueOf(e.getMessage() + '\r\n' + 'stacktrace: ' + '\r\n' + stackTrace + '\r\n');
            res.statusCode = 400;
            return;        
        }   

		res.responseBody = Blob.valueOf('FATAL ERROR -- should not have reached here');        
        res.statusCode = 500;
		return;        
    }

}