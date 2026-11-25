// 20261124-1717
debugger;

const WebSocket = require('ws');
const https = require("node:https");
const fs = require("node:fs");
const zlib = require("zlib");
const PubNub = require('pubnub');

function getCallerInfo() {
  const originalFunc = Error.prepareStackTrace;

  try {
    Error.prepareStackTrace = (_, stack) => stack;
    const err = new Error();
    
    // err.stack now contains an array of CallSite objects
    const currentCallStack = err.stack; 

    // Index 0: getCallerInfo
    // Index 1: the logger function (e.g., logger.info)
    // Index 2: the method that called your logger
    const caller = currentCallStack[2]; 

    if (caller) {
      return {
        methodName: caller.getFunctionName() || 'anonymous',
        fileName: caller.getFileName(),
        lineNumber: caller.getLineNumber()
      };
    }
  } catch (e) {
    // Fallback safely if stack trace capturing breaks
  } finally {
    Error.prepareStackTrace = originalFunc;
  }

  return null;
}

function logmsg(msg, obj) {

    const caller = getCallerInfo();
    const prefix = caller ? `[${caller.methodName}:${caller.lineNumber}]` : '[unknown]';

    if (typeof msg === 'string') {
        console.log(prefix + '|' + msg);
        if ( obj )
            console.log(obj);
    }
}

function isNullOrEmpty(str) {
    return str == null || str.length === 0;
}

function getTimestamp() {
    const now = new Date();

    const pad = (n) => String(n).padStart(2, '0');

    const year = now.getFullYear();
    const month = pad(now.getMonth() + 1); // Months are 0-indexed
    const day = pad(now.getDate());
    const hours = pad(now.getHours());
    const minutes = pad(now.getMinutes());
    const seconds = pad(now.getSeconds());

    return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

function generateRandCode() {
    return Math.floor(10000000 + Math.random() * 90000000);
}

// --- BEGIN globals


const uuid = 'nodecdpproxy.js';

const pubnub = new PubNub({
    publishKey: 'pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66',
    subscribeKey: 'sub-c-62ba6c3d-b786-4be3-a033-e472ab227774',
    userId: 'nodecdpproxy.js',
});

const channel_name = 'clientid_88992233_JS_client';

const REQUEST_CHANNEL = channel_name;
const RESPONSE_CHANNEL = channel_name;

// log status notifications
pubnub.addListener({
  status: (statusEvent) => {
    switch (statusEvent.category) {
      case 'PNConnectedCategory':
        logmsg('Successfully connected to PubNub!'); //
        break;
      case 'PNSubscriptionChangedCategory':
        logmsg('statusEvent: Channel subscription list updated.'); //
        break;
      case 'PNDisconnectedCategory':
        logmsg('Intentionally disconnected.'); //
        break;
      case 'PNDisconnectedUnexpectedlyCategory':
        logmsg('Network connection lost! SDK will auto-retry.'); //
        break;
      case 'PNAccessDeniedCategory':
        console.error('PAM Authorization failed (invalid token/keys).'); //
        break;
    }
  }
});

pubnub.subscribe({ channels: [RESPONSE_CHANNEL] });

const subscription = pubnub.channel(RESPONSE_CHANNEL).subscription();

subscription.onMessage = processIncommingMsg;

subscription.subscribe();

let pbmessages = [];

function assembleChunks(chunks) {

    let bodystr = "";

    for ( let i = 0; i<chunks.length; i++) {
        let chunkobj = chunks[i];

        let chunkindex = chunkobj['chunkindex'];
        let chunksize = chunkobj['chunksize']
        let chunkcount = chunkobj['chunkcount'];
        let remainderlength = chunkobj['remainderlength']
        let imagedata = chunkobj['imagedata'];

        if ( ! ( chunkindex == i && chunks.length == chunkcount ) ) {
            throw new Error("chunks not valid -- mismatch index and/or chunk count");
        }

        bodystr += imagedata;
    }

    return bodystr;
}

function processIncommingMsg(messageEvent) {

    let result = messageEvent.message;

    if ( ! result ) {
        throw new Error('builtincmd is null');
    }

    logmsg(`received message from: ${result.source} to: ${result.destination} ts: ${result.ts} cmd: ${result.builtincmd} cmdid: ${result.cmdid} resultid: ${result.resultid}`);

    if ( ! result.builtincmd == 'ProcessCDPBridge' ) {
        return
    }

    if ( result.destination != 'nodecdpproxy.js' ) {
        return;
    }

    let resultid = result.resultid;

    if ( ! resultid ) {
        throw new Error('resultid is null');
    }

    let ischunked = result['ischunked']
    let payload = result['result']
    let isbase64 = result['isbase64']

    if ( ! ischunked ) {
        pbmessages[String(resultid)] = result;
    } else {
        let chunk = {
            "imagedata":payload['imagedata'],
            "chunkcount":payload['chunkcount'],
            "chunkindex":payload['chunkindex'],
            "chunksize":payload['chunksize'],
            "remainderlength":payload['remainderlength']
        };

        let pbmsg = pbmessages[String(resultid)];

        if ( ! pbmsg ) {
            pbmsg = result;

            pbmsg['chunkobj'] = [ chunk ]; 
            pbmessages[String(resultid)] = pbmsg;
        } else {
            pbmsg['chunkobj'].push(chunk);
        }

        if ( payload['chunkindex'] == payload['chunkcount'] - 1 ) {
            let chunks = pbmsg['chunkobj'];
            bodystr = assembleChunks(chunks);
            pbmsg['result'] = bodystr;
        } else {
            return;
        }
    }
    
    pbmsg = pbmessages[String(resultid)];
    payload = pbmsg['result'];

    if ( pbmsg['isbase64'] ) {
        payload = Buffer.from(payload, 'base64').toString('utf8');
    }

    logmsg('payload: ', payload);

    if ( wss.clients.size == 0 ) {
        logmsg('no connected clients -- skipping');
        return;
    }

    wss.clients.forEach((client) => {
        if (client.readyState === 1) { // 1 = WebSocket.OPEN
            client.send(payload);
        }
    });

}

const wss = new WebSocket.Server({ port: 8123 });
logmsg('Local WebSocket proxy listening on ws://localhost:8123');

wss.on('connection', (ws) => {
    logmsg('Local client connected');

    ws.on('message', async (rawData) => {

        try {
            const base64String = Buffer.from(rawData).toString('utf8');

            logmsg('incomming message: '+base64String);
            
            return;

            let payload = {

            };

            const result = await pubnub.publish({
                channel: TARGET_CHANNEL,
                message: payload,
            });

            logmsg('Published to PubNub. Timetoken:', result.timetoken);

            // ws.send(JSON.stringify({ status: 'forwarded', timetoken: result.timetoken }));
        } catch (error) {
            logmsg('PubNub publish error:', error);
            // ws.send(JSON.stringify({ status: 'error', message: error.message }));
        }
    });

    ws.on('close', () => {
        logmsg('Local client disconnected');
    });

});
