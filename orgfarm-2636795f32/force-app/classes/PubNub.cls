// https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce.com
// storagevault941@agentforce.com
// As2df2gh!
//
// set NODE_PATH=C:\Users\LC2022\AppData\Local\sfdx\client\node_modules
// "C:\Program Files\Adobe\Adobe Creative Cloud Experience\libs\node.exe" --no-deprecation "%~dp0\..\client\bin\run" %*
//
// & C:\Users\LC2022\AppData\Local\sfdx\bin\sf.cmd
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd org login web --alias storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd deploy metadata -m ApexClass:PubNub -o storagevault941@agentforce.com
// cmd /k F:\__Binaries\sfdx\client\bin\sf.cmd project retrieve start -m ApexClass:PublicRestService -o storagevault941@agentforce.com



global without sharing class PubNub {


    public static Map<String, String> convertExceptionToMap(Exception ex) {
        Map<String, String> errorMap = new Map<String, String>();

        if (ex != null) {
            errorMap.put('ExceptionType', ex.getTypeName());
            errorMap.put('Message', ex.getMessage());
            errorMap.put('StackTrace', ex.getStackTraceString());
            errorMap.put('LineNumber', String.valueOf(ex.getLineNumber()));

            // Handle inner/cause exceptions if they exist
            if (ex.getCause() != null) {
                errorMap.put('Cause', ex.getCause().getMessage());
            }
        }

        return errorMap;
    }

    public static String getTimestamp() {
        Datetime currentDatetime = System.now();

        Long unixTimestamp = currentDatetime.getTime(); 

        return String.valueOf(unixTimestamp);
    }

    public static String getRandomCode() {

        // Generate a random integer between 10,000,000 and 99,999,999
        Integer min = 10000000;
        Integer max = 99999999;
    
        Integer randomValue = Math.mod( Math.abs(Crypto.getRandomInteger()), (max - min + 1) ) + min;

        return String.valueOf(randomValue);
    }

    static String publishKey = 'pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc';
    public static String subscribeKey = 'sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd';
    public static String UUID = 'salesforce_client_' + PubNub.getRandomCode();
    public static String baseUrl  = 'ps.pndsn.com';
   
    public String channel = 'clientid_88992233_JS_client';
    
    public String getReceiveUrl() {
        return getReceiveUrl('0');
    }

    public String getReceiveUrl(string timetoken) {
        return this.receiveUrl + '/' + timetoken + '?uuid=' + PubNub.UUID;
    }

    public String receiveUrl {
        get {
            // 'https://'+PubNub.baseUrl+'/v2/subscribe/'+PubNub.subscribeKey+'/'+this.channel+'/<callback>/<timetoken>?uuid=<uuid>
            return 'https://'+PubNub.baseUrl+'/v2/subscribe/'+PubNub.subscribeKey+'/'+this.channel+'/0';
        }
    }

    public String publishUrl {
        get {
            return 'https://'+PubNub.baseUrl+'/publish/'+PubNub.publishKey+'/'+PubNub.subscribeKey+'/0/' + this.channel + '/0?uuid='+PubNub.UUID;
        }
    }

    public Map<string, string> publishMessage(Map<String, String> msgdict) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(this.publishUrl);
        req.setMethod('POST');

        if ( msgdict == null )
            msgdict = new Map<String, String>();

        if ( ! msgdict.containsKey('ts') )
            msgdict.put('ts', PubNub.getTimestamp());

        String jsonBody = JSON.serialize(msgdict);

        Logger.LogSys(jsonBody, 'publishMessage');

        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        req.setBody(jsonBody);

        Http http = new Http();
        HTTPResponse res = http.send(req);

        try {
            jsonBody = res.getBody(); 
            List<object> ret = (List<object>) JSON.deserializeUntyped(jsonBody);

            Map<string, string> out = new Map<string, string>();

            if ( ret != null && ret.size() > 2 ) {
                Object obj = ret[0];

                if ( obj instanceof String ) {
                    out.put('success_flag', String.valueOf(ret[0]));
                } else if ( obj instanceof Integer ) {
                    out.put('success_flag', String.valueOf(Integer.valueOf(ret[0])));
                }

                obj = ret[1];

                if ( obj instanceof String ) {
                    out.put('description', String.valueOf(ret[1]));
                } else if ( obj instanceof Integer ) {
                    out.put('description', String.valueOf(Integer.valueOf(ret[1])));
                }

                obj = ret[2];

                if ( obj instanceof String ) {
                    out.put('timetoken', String.valueOf(ret[2]));
                } else if ( obj instanceof Integer ) {
                    out.put('timetoken', String.valueOf(Integer.valueOf(ret[2])));
                }

            }

            return out;
        } catch (Exception e) {
            return PubNub.convertExceptionToMap(e);
        }

        // return null;
    }

    // TODO fix for depth: JSON.deserializeUntyped several depths before type is string
    public List<Map<string, object>> receiveMessages(string timetoken) {
        Logger.LogSys('starting with timetoken='+timetoken, 'receiveMessages');

        HttpRequest req = new HttpRequest();
        string uri = this.getReceiveUrl(timetoken);

        Logger.LogSys(uri, 'receiveMessages');

        req.setTimeout(30000); 
        req.setEndpoint(uri);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');

        Http http = new Http();
        HTTPResponse res = http.send(req);
        
        string jsonstr = res.getBody();

        List<Map<string, object>> messages = null;

        try {
            Map<String, Object> obj = (Map<String, Object>) JSON.deserializeUntyped(jsonstr);
            
            Set<String> keys = obj.keySet();

            if ( ! keys.contains('m') ) {
                return null;
            }

            List<object> omessages = (List<object>) obj.get('m');
            messages = new List<Map<string, object>>();
            
            for ( object omsg : omessages ) {
                Map<string, object> tmsg = (Map<string, object>) ((Map<string, object>) omsg).get('d');

                messages.add(tmsg);
            }

        } catch (Exception ex) {
            Map<string, string> exmap = PubNub.convertExceptionToMap(ex);
            jsonstr = JSON.serialize(exmap);
            Logger.LogSys(jsonstr, 'receiveMessages');
        }

        return messages;
    }

    public Map<string, string> receiveMessage() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(this.getReceiveUrl());
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');

        Http http = new Http();
        HTTPResponse res = http.send(req);

        System.debug(res.getBody());

        Map<string, string> ret = new  Map<string, string>();

        return null;
    }

}



/* pubnub incomming message JSON 
{
  "t": {
    "t": "17902824113919203",
    "r": 23
  },
  "m": [
    {
      "a": "2",
      "f": 0,
      "i": "user-277",
      "p": {
        "t": "17902824113919203",
        "r": 22
      },
      "k": "sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd",
      "c": "clientid_88992233_JS_client",
      "d": {
        "builtincmd": "SendTestMessage",
        "source": "client_pubnub.html",
        "destination": "pscdp.relay.ps1",
        "cmdid": 96887852,
        "ts": 1790282410317
      }
    }
  ]
}
*/