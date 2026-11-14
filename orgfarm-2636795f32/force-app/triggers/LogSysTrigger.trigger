trigger LogSysTrigger on LogEvent__e (after insert) {
    List<LogSys__c> logmsgs = new List<LogSys__c>();

    for (LogEvent__e event : Trigger.New) {
        LogSys__c logmsg = new LogSys__c();
        logmsg.LogMsg__c = event.Payload__c;
        logmsgs.add(logmsg);
    }

    if (!logmsgs.isEmpty()) {
        insert logmsgs;
    }

}