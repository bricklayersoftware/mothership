// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd deploy metadata -m ApexClass:Logger -o storagevault941@agentforce.com
global without sharing class Logger {     

    public static string logsessionid = Helper.GetRandomNum(8);
    public static integer logindex = 1;

    public static void TryEmptyLogs() {
        Integer upperLimit = 100;
        Integer randomNumber = Math.floor(Math.random() * upperLimit).intValue();
        
        if ( randomNumber >= 80 ) {
            return;    
        }

        EmptyLogs();
    }
    
    public static void EmptyLogs() {
        try {
            List<Logger__c> recordsToKeep = [ SELECT Id 
                                                            FROM Logger__c 
                                                            ORDER BY CreatedDate 
                                                            DESC LIMIT 25 ];
            
            Datetime lastHour = System.now().addHours(-1);

            List<Logger__c> logs = [ SELECT Id, LastModifiedDate 
                                                   FROM Logger__c 
                                                   WHERE LastModifiedDate <= :lastHour 
                                                   AND Id NOT IN :recordsToKeep ];
            
            delete logs;
            
            logs = [ SELECT ID FROM Logger__c WHERE IsDeleted = true ];
            
            if ( logs.isEmpty() )
                return;
            
            Database.emptyRecycleBin(logs);
            
        } catch (Exception ex) {
            LogSysEx(ex);
        }
    }
    
    public static void LogSysEx(Exception ex) {
    	string expstr = '';
		expstr = 'getMessage: '+ex.getMessage();
        expstr += '|getTypeName: '+ex.getTypeName();
        expstr += '|getLineNumber: '+ ex.getLineNumber();
        expstr += '|getStackTraceString: '+ex.getStackTraceString();
    
        LogSys(expstr);
    }
    
    public static void LogSys(string msg) {
        LogSys(msg, '');
    }

    public static void LogSys(string msg, string prefix) {

        try {
            if ( String.isBlank(prefix) ) {
                prefix = 'LogSys';
            }

            string logmsgstr = prefix + '|'+logsessionid + '|' + String.valueOf(logindex) +'|'+msg;
            
            LogEvent__e event = new LogEvent__e( Payload__c = logmsgstr);
            
            Database.SaveResult sr = EventBus.publish(event);

            if (sr.isSuccess()) {
                logindex = logindex + 1;

                // The event was successfully enqueued. 
                System.debug('Successfully enqueued event for publishing.');
                
                // You can also track the Event UUID for correlation later if needed
                String eventUuid = EventBus.getOperationId(sr);
                System.debug('Event UUID: ' + eventUuid);
            } else {
                // The event failed validation or failed to enter the queue
                for(Database.Error err : sr.getErrors()) {
                    System.debug('Enqueue Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                }
            }
            
            System.debug(logmsgstr);

        } catch (Exception ex) {
            String exceptionString = String.format('Exception Type: {0} | Message: {1} | Line: {2} \nStack Trace: {3}', 
                new List<Object>{
                    ex.getTypeName(),
                    ex.getMessage(),
                    ex.getLineNumber(),
                    ex.getStackTraceString()
                } );

            System.debug(exceptionString);
        }

        System.debug('LogSys');
    }
    
    public static void PublishMsgLogger(string source, string tsource, string msg, RestRequest req) {
        PublishEventLogger('log_msg', msg, source, tsource, null, req);
    }
    
    // source = http endpoint --> ping.php, retrieve.php, upload.php, logmsg.php, relay.php
    // tsource = the machine generating the message (i.e., endpoint) -- script filename publishing event
    public static Logger__c PublishEventLogger(string event, string logmsgstr, string source, string tsource, Map<string, string> kvp, RestRequest req) {
        Logger__c logmsg = new Logger__c();

        Map<string,string> reqkvp = Helper.KVPLCase(req.params);
		
        string clientid = reqkvp.containsKey('clientid') ? reqkvp.get('clientid') : null;
            
        kvp = kvp == null ? new Map<string, string>() : kvp;

        String ipAddress = req.remoteAddress;
        String userAgent = req.headers.get('User-Agent');

		string sysmsg = 'PublishEventLogger|starting';
        sysmsg += '|clientid='+clientid;
        sysmsg += '|event='+ event;
        sysmsg += '|source='+source;
        sysmsg += '|tsource='+tsource;
        sysmsg += '|logmsgstr='+logmsgstr;
        sysmsg += '|kvp='+Helper.MapToKVPStr(kvp);
        
        LogSys(sysmsg);
        
        logmsg.Event__c = event;
        logmsg.ClientID__c = clientid;        
        logmsg.TSource__c = tsource; 
        logmsg.Source__c = source;
        logmsg.UserAgent__c = userAgent; 
        logmsg.ip_addr__c = ipAddress;

        logmsg.LogID__c = reqkvp.containsKey('logid') ? reqkvp.get('logid') : '-1';
        logmsg.BatchID__c = reqkvp.containsKey('batchid') ? reqkvp.get('batchid') : null;
        logmsg.ScriptVersion__c = reqkvp.containsKey('script_version') ? reqkvp.get('script_version'):null;
		logmsg.SessionID__c = reqkvp.containsKey('sessionid') ? reqkvp.get('sessionid') : null;
        
        string t_sessionts = reqkvp.containsKey('sessionts') ? reqkvp.get('sessionts') : null;
        t_sessionts = String.isBlank(t_sessionts) ? helper.GetTimestamp() : t_sessionts;
		logmsg.SessionTS__c = t_sessionts;

		logmsg.Username__c = reqkvp.containsKey('username') ? reqkvp.get('username') : null;
        logmsg.Machinename__c = reqkvp.containsKey('machinename') ? reqkvp.get('machinename') : null;
		    
        logmsg.LogMsg__c = logmsgstr;
        logmsg.KVP__c = helper.MapToKVPStr(kvp);

        Database.SaveResult sr = Database.insert(logmsg, false);

        if (!sr.isSuccess()) {
            for (Database.Error err : sr.getErrors()) {
                if (err.getStatusCode() == StatusCode.STORAGE_LIMIT_EXCEEDED) {
                    TryEmptyLogs();
                }
            }
        }
        
        LogSys('PublishEventLogger|finished|logmsg.ID='+logmsg.ID);

        return logmsg;
    }

}