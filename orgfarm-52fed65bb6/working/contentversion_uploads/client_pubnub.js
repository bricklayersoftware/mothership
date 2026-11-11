import * as helper from "./client_pubnub.helper.js?";

const PubNub = window.PubNub;

helper.LogMsg("--- JSPubNub ---");

function MessageToPayload(messageEvent, type, tmsgindex) {
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

class JSPubNubError extends Error {
    constructor(message) {
        super(message);
        this.name = "JSPubNubError";
    }
}


class JSPubNub {
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

    sendMessage(payload) {
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
                    helper.LogMsg("Publish failed: " + status.toJSON());
                } else {
                    payload.response = response;
                    helper.LogMsg(
                        "Message published successfully with timetoken:" +
                        response.timetoken
                    );
                }
            }
        );
    }

    constructor(pubnubconfig, client_channel) {
        this.pubnubconfig = pubnubconfig;
        this.client_channel = client_channel;
    }

    connect() {
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
                    helper.logmsg("new PubNub message received: ", messageEvent);

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

class JSCDPCommand {}

class JSCDPResult {}

class JSCDPTarget {}

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

export { MessageToPayload, JSCDP, JSPubNub };
