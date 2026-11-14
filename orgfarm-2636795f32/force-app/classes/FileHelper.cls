// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd org login web --alias storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd deploy metadata -m ApexClass:FileHelper -o storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd project retrieve start -m ApexClass:FileHelper -o storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd apex generate class --name FileHelper --output-dir force-app/main/default/classes

global without sharing class FileHelper {

    public static ContentVersion GetContentVersion(string filename) {
    	ContentVersion cv = null;
        
        List<ContentVersion> cvs = [ SELECT VersionData, Title, PathOnClient, FileExtension 
                                     FROM ContentVersion 
                                     WHERE Title = :filename //AND PathOnClient = '/'+filename 
                                     ORDER BY LastModifiedDate DESC
                                     LIMIT 1 ];

        if ( ! cvs.isEmpty() )
            cv = cvs[0];
            
        return cv;
    }

    public static ContentVersion CreateContentVersion(string filename, blob fileBlob) {
    	ContentVersion cv = null;
        
        List<ContentVersion> existingFiles = [ SELECT ContentDocumentId FROM ContentVersion WHERE Title = :filename AND IsLatest = true LIMIT 1 ];

        cv = new ContentVersion();

        Id currentUserId = UserInfo.getUserId();

        cv.Title = filename;
        cv.PathOnClient = '/' + filename; 
        cv.VersionData = fileBlob;
        cv.IsMajorVersion = true;
        // cv.ContentLocation = 'C'; // 'C' indicates it's stored in Salesforce
        cv.IsMajorVersion = true;
        cv.SharingPrivacy = 'N'; 
        cv.FirstPublishLocationId = currentUserId; // Automatically links the file to the user

        if ( ! existingFiles.isEmpty() ) {
            cv.ContentDocumentId = existingFiles[0].ContentDocumentId;
        }
        
        Database.SaveResult sr = Database.insert(cv, false);

        if (sr.isSuccess()) {
            // System.debug('Successfully inserted Account. ID: ' + sr.getId());
        } else {
            /*
            // Operation failed, loop through the errors
            for(Database.Error err : sr.getErrors()) {
                System.debug('Error status code: ' + err.getStatusCode());
                System.debug('Error message: ' + err.getMessage());
                System.debug('Fields that affected this error: ' + err.getFields());
            }
                */
        }
                        
        // string msgstr = 'filesize='+String.valueOf(fileBlob.size())+'|'+'filename='+t_filename + '|'+'recordid='+String.valueOf(cv.Id);

        return cv;
    }

    public static List<string> GetFilesList() {
        List<string> files = new List<string>();

        List<AggregateResult> results = [
            SELECT Title, MAX(LastModifiedDate) latestModDate
            FROM ContentVersion
            WHERE IsLatest = true 
            GROUP BY Title
            ORDER BY MAX(LastModifiedDate) DESC
        ];
        
        for (AggregateResult ar : results) {
            String fileTitle = (String) ar.get('Title');
            files.add(fileTitle);
        }

        return files;
    }

}