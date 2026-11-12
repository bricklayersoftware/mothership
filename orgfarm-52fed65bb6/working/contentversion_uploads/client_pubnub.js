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

    constructor() {
        this.sendQueue = [];

        this.responses = [];

        this.consolecalls = [];

        this.commands = [];
        this.results = [];
        this.errors = [];

        this.targets = [];
    }

    updatesHandler = (event) => {
        throw new JSCDPError('updatesHandler not implemented');
    };

    getTargetsList() {
        return this.targets;
    }

    setTargetsList(stargets) {
        // TODO convert to array of JSCDPTarget objects
        this.targets = stargets;

        this.updatesHandler('Targets');
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

        try {
            return cmdfunc.call(this, message);
        } catch (ex) {
            helper.logmsg(ex);
        }
    }

    process_GetTargetScreenCapture(result, message) {

        let chunkcount = message['chunkcount']
        let chunksize = message['chunksize']
        let chunkindex = message['chunkindex']
        let remainderlength = message['remainderlength']
        let imagedata = result['imagedata']

        screencapture_chunks.push({
            chunkcount: chunkcount,
            chunksize: chunksize,
            chunkindex: chunkindex,
            remainderlength: remainderlength,
            imagedata: imagedata
        });

        if (chunkindex == chunkcount - 1) {
            this.combineChunks();
        }
    }

    combineChunks() {

        screencapture_chunks.sort((a, b) => Number(a.chunkindex) - Number(b.chunkindex));

        let imagestr = '';

        for (let i = 0; i < screencapture_chunks.length; i++) {
            imagestr += screencapture_chunks[i].imagedata;
        }

        screencapture_chunks = [];

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

    process_GetClientCommands(result) {
        refreshCommandsTable(result);
    }

    process_GetTargetHTML(result, message) {
        helper.logmsg('GetTargetHTML');
    }

    process_RefreshDOM(result, message) {

        result = atob(result);

        try {
            result = JSON.parse(result);
        } catch (ex) {
            helper.logmsg(ex);
        }

        result = result || {};

        refreshTable('domList', result);

        reloadJsonTree(result);
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