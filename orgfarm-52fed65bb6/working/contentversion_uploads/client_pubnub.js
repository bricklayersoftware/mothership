class JSPubNub {

    sendMessage(payload) {

    }

    constructor(pubnub) {
        this.pubnub = pubnub;
    }
}

class JSCDPCommand {
}

class JSCDPResult {
}

class JSCDPTarget {

}

class JSCDP {
    
    constructor() {
        this.sendQueue = [];

        this.responses = [];
        
        this.consolecalls = [];

        this.commands = [];
        this.results = [];
        this.errors = [];

        this.targets = [];
    }

    processPBMessage(pbmsg) {
        // TODO pbmsg should be destined for client_pubnub.html 
    }
}
