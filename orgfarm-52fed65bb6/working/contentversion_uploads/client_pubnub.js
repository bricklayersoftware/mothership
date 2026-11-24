const helper = window.helper;
const PubNub = window.PubNub;
const jsui = window.jsui;

helper.LogMsg("--- client_pubnub.js ---");

export function MessageToPayload(messageEvent, type, tmsgindex) {
    // const keys = Object.getOwnPropertyNames(messageEvent).filter( (p) => typeof messageEvent[p] === 'string' );

    const eventObj = { ...messageEvent };

    if (Object.hasOwn(eventObj, "message")) delete eventObj.message;

    let payload = {
        type: type,
        event: eventObj,
        message: messageEvent.message,
        ts: Date.now(),
        msgindex: tmsgindex
    };

    return payload;
}

export class JSPubNubError extends Error {
    constructor(message) {
        super(message);
        this.name = "JSPubNubError";
    }
}

export class JSCDPError extends Error {
    constructor(message) {
        super(message);
        this.name = "JSCDPError";
    }
}

export class JSPubNub {
    msgindex = 1;
    messagelist = [];
    client_channel = "clientid_88992233_JS_client";

    pubnubconfig = {
        publishKey: "pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66",
        subscribeKey: "sub-c-62ba6c3d-b786-4be3-a033-e472ab227774",
        userId: "client_pubnub.html"
    };

    pubnub = null;

    messageHandler = null;

    getMessages() {
        return this.messagelist;
    }

    sendMessage(payload, logmsg) {
        if ( ! logmsg )
            logmsg = false;

        if ( logmsg ) {
            helper.logmsg('sendMessage: ', payload);
        }

        if (!this.pubnub) {
            throw new JSPubNubError('not connected to pubnub');
        }

        this.pubnub.publish(
            {
                message: payload,
                channel: this.client_channel
            },
            (status, response) => {
                if (status.error) {
                    payload.error = status;

                    if ( logmsg ) {
                        helper.LogMsg("Publish failed: " + status.toJSON());
                    }
                } else {
                    payload.response = response;

                    if ( logmsg ) {
                        helper.LogMsg(
                            "Message published successfully with timetoken:" +
                            response.timetoken
                        );
                    }
                }
            }
        );
    }

    constructor(pubnubconfig, client_channel) {
        this.pubnubconfig = pubnubconfig;
        this.client_channel = client_channel;
    }

    connect() {
        helper.logmsg('connecting: ', this.pubnubconfig);
        this.pubnub = new PubNub(this.pubnubconfig);

        let pbinst = this;

        this.pubnub.addListener({
            status: function (statusEvent) {
                let msgstr = "";
                try {
                    msgstr = JSON.stringify(statusEvent);
                } catch (ex) {}

                helper.logmsg("status event: " + msgstr);

                if (statusEvent.category === "PNConnectedCategory") {
                    helper.logmsg(
                        "PubNub Status Notification -- Successfully connected locally!"
                    );
                }
            },

            presence: function (messageEvent) {
                helper.logmsg("presence event: ", msgstr);
            },

            message: function (messageEvent) {
                try {
                    let payload = MessageToPayload(
                        messageEvent,
                        "PubNubMessage",
                        pbinst.msgindex++
                    );

                    pbinst.messagelist.push(payload);

                    if (pbinst.messageHandler) {
                        pbinst.messageHandler(messageEvent);
                    }
                } catch (ex) {
                    helper.logmsg(ex);
                }
            }
        });

        this.pubnub.subscribe({
            channels: [pbinst.client_channel]
        });
    }
}

export class JSCDPCommand {}

export class JSCDPResult {}

export class JSCDPTarget {}

export class JSCDP {
    screencapture_chunks = null;
    targets = [];

    commands = [];
    results = [];
    errors = [];
    responses = [];
    consolecalls = [];
    browserversion = null;
    targets = [];
    domlist = {};

    chunkedMessages = [];

    constructor() {
        this.sendQueue = [];

        this.responses = [];

        this.consolecalls = [];

        this.commands = [];
        this.results = [];
        this.errors = [];

        this.targets = [];
    }

    updatesHandler = (event, data) => {
        throw new JSCDPError('updatesHandler not implemented');
    };

    getTargetsList() {
        return this.targets;
    }

    getConsoleLogs() {
        return this.consolecalls;
    }

    getCommands() {
        return this.commands;
    }

    setCommands(commands) {
        this.commands = commands;

        this.updatesHandler('Commands');
    }

    setTargetsList(stargets) {
        this.targets = stargets;

        this.updatesHandler('Targets');
    }

    getTargetDOM(targetId) {
        return this.domlist[targetId];
    }

    setTargetDOM(domobj, targetId) {
        this.domlist[targetId] = domobj;
        this.updatesHandler('DOM', { "targetId": targetId } );
    } 

    setConsoleLogs(logs) {
        this.consolecalls = logs;

        this.updatesHandler('ConsoleLogs');
    }

    processPBMessage(messageEvent) {
        let message = messageEvent.message;

        if (message.destination != 'client_pubnub.html') {
            return;
        } else if (message.builtincmd == 'BROADCAST') {
            return;
        }

        let cmdfuncname = "process_" + message.builtincmd;
        let cmdfunc = null;

        if (typeof this[cmdfuncname] === "function") {
            cmdfunc = this[cmdfuncname];
        } else {
            throw new JSCDPError(`built in cmd name does not exist ${cmdfuncname}`)
        }

        let resultid = '';


        resultid = message['resultid'];

        if ( message['ischunked'] ) {
            let messageChunks = this.chunkedMessages[resultid];

            if ( ! messageChunks ) {
                messageChunks = [];
            }

            messageChunks.push(message);
            this.chunkedMessages[resultid] = messageChunks;

            if ( message.chunkindex != message.chunkcount - 1 ) {
                return
            } else {
                let resultstr = this.combineChunks(messageChunks);
                message['result'] = resultstr;
            }

        }

        return cmdfunc.call(this, message);
    }

    process_GetTargetScreenCapture(message) {

        let result = message.result;

        try {
            if (message.isbase64) {
                result = atob(result);
            }

            result = JSON.parse(result);
        } catch (e) {

        }

        insertScreenCapture(result);
    }

    combineChunks(messageChunks) {

        messageChunks.sort((a, b) => Number(a.chunkindex) - Number(b.chunkindex));

        let imagestr = '';

        for (let i = 0; i < messageChunks.length; i++) {
            imagestr += messageChunks[i].result.imagedata;
        }

        return imagestr;
    }

    insertScreenCapture(imagestr) {
        const containerDiv = document.getElementById('screen_capture');

        const base64String = 'data:image/png;base64,' + imagestr;

        const img = document.createElement('img');

        img.src = base64String;
        img.alt = 'Inserted Base64 Image';

        containerDiv.appendChild(img);
    }

    process_RefreshTargets(message) {
        let result = message.result;

        try {
            if (message.isbase64) {
                result = atob(result);
            }

            result = JSON.parse(result);
        } catch (e) {

        }

        this.setTargetsList(result);
    }

    process_GetTargetText(result) {
        console.log('GetTargetText');
        // TODO implement -- show text in ui
    }

    process_GetClientCommands(message) {
        let result = message.result;

        try {
            if ( result ) {
                result = atob(result);
            }

            result = JSON.parse(result);
        } catch (e) {

        }
        
        this.setCommands(result);

    }

    process_GetTargetHTML(result, message) {
        helper.logmsg('GetTargetHTML');
    }

    process_RefreshDOM(message) {

        let result = message.result;

        try {
            if ( result ) {
                result = atob(result);
            }

            result = JSON.parse(result);
        } catch (e) {

        }

        this.setTargetDOM(result, message['targetId']);
    }

    process_GetFrontendUrls(result, message) {

        if (Array.isArray(result) && result.length > 0) {
            result = result[0];
        }

        document.getElementById('devtoolsFrontendUrl').value = result.devtoolsFrontendUrl;
    }

    process_GetTargets(message) {
        let result = message.result;

        try {
            if (message.isbase64) {
                result = atob(result);
            }

            result = JSON.parse(result);
        } catch (e) {

        }

        let targets = result;

        this.setTargetsList(targets);
    }

    process_GetConsoleLogs(message) {
        let result = message.result;

        try {
            if (message.isbase64) {
                result = atob(result);
            }

            result = JSON.parse(result);
        } catch (e) {

        }

        this.setConsoleLogs(result);
    }

    process_ExecEvaluate(result, message) {

        result = atob(result);
        try {
            result = JSON.parse(result);
        } catch (ex) {

        }

        result = result || {};

        keys = ['builtincmd', 'cmdid', 'resultid', 'targetId'];

        keys.forEach(key => {
            result[key] = message[key];
        });

        addResult(result);
    }
}