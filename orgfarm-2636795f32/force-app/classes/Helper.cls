global without sharing class Helper {
    public class GenericException extends Exception {}
    
    public static string GetTimestamp() {
        return Datetime.now().format('yyyyMMddHHmmssSSS');
    }

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
    
    public static string MapToKVPStr(Map<string, string> inputMap) {
        string outstr = '';
        
        if ( inputMap == null || inputMap.size() == 0 )
            return outstr;
        
        Integer i = 0;
        for (String key : inputMap.keySet()) {
            
            String value = inputMap.get(key);
            
            if ( i >= 1 ) 
                outstr += '|';
            
            outstr += '['+key+']=['+value+']';
            
			i += 1;                        
        }

        return outstr;
    }

    public static Map<string,string> KVPLCase(Map<string,string> kvp) {
        Map<string,string> outkvp = new Map<string,string>();

        if ( kvp == null || kvp.isEmpty() ) 
            return outkvp;
                
        for ( String key : kvp.keySet() ) {
            string value = kvp.get(key);
            outkvp.put(key.toLowerCase(), value);
        }
        
        return outkvp;
    }   
        
    public static string getFilenameExt(string filename) {
        filename = filename.trim();
        return String.isBlank(filename) ? '' : filename.substringAfterLast('.').toLowerCase();
    }
}