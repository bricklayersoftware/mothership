public class LoggerTriggerHandler {
    public static string logsessionid = GetRandomNum(8);
    public static integer logindex = 1;

    public static string GetRandomNum(integer n) {
        
        if ( n <= 0 )
            return '';
        
        String randStr = '';
        Integer randomInt = -1;
        
        while ( randStr.length() < n ) {
            randomInt = Integer.valueOf(Math.random() * 90000000 + 10000000);
            randStr = randStr + String.valueOf(randomInt);
        }        
        
        return randStr.substring(0,n-1);
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
        try {
            string logmsgstr = 'Trigger|' + logsessionid + '|' + String.valueOf(logindex) +'|'+msg;

            LogEvent__e event = new LogEvent__e(
                Payload__c = logmsgstr
            );
            
            EventBus.publish(event);      
            logindex = logindex + 1;
        } catch (Exception ex) {
            
        }
    }

    public static Map<string,string> LogMsgToKVP(string logmsgstr) {
        Map<string,string> outkvp = new Map<string,string>();
        
        // [event]=[init_jobcode]|[jobcode]=[3967267]|[jobrowid]=[a04fj0000023mTZAAY]
        List<String> parts = logmsgstr.split('\\|');
        
        if ( parts.size() <= 0 ) {
            LoggerTriggerHandler.LogSys('LogMsgToKVP: parts is zero');

        	return outkvp;    
        }
        
        for ( String part : parts ) {
        	List<string> pair = part.split('=');
            
            if ( pair.size() != 2 ) {
            	continue;    
            }
            
            string key = pair[0];
            string value = pair[1];
            
            if ( key.mid(0,1) == '[' ) {
                key = key.mid(1,key.length()-1);
            }
            
            if ( key.mid(key.length()-1,1) == ']' ) {
                key = key.mid(0,key.length()-1);
            }
            
            if ( value.mid(0,1) == '[' ) {
                value = value.mid(1,value.length()-1);
            }

            if ( value.mid(value.length()-1,1) == ']' ) {
                value = value.mid(0,value.length()-1);
            }
            
            outkvp.put(key,value);
        }
        
        return outkvp;
    }
    
}