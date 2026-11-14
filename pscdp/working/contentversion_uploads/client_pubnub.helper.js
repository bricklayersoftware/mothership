let logmsg_index = 0;

export function getRandomCode(n = 8) {
  let base = 10 ** (n - 1);
  let top = 10 * base;
  return Math.floor(base + Math.random() * (top - base));
}

export function ErrorToJson(err) {
  if ((!err) instanceof Error) {
    return "";
  }

  let jsonstr = JSON.stringify(err, (key, val) => {
    if (val instanceof Error) {
      return {
        name: val.name,
        message: val.message,
        stack: val.stack
      };
    }

    return val;
  });

  return jsonstr;
}

export function TryStringify(jsonObj) {
  try {
    return JSON.stringify(jsonObj);
  } catch (ex) {
    return null;
  }
}

export function isNullOrEmpty(value) {
    return value == null || (typeof value === "string" && value.trim().length === 0);
}

function getLastEndpoint(urlString) {
    try {
        // 1. Parse the URL using the native browser/Node.js API
        const url = new URL(urlString);

        // 2. Grab the clean path, split by slashes, and filter out any trailing slash empty strings
        const segments = url.pathname.split('/').filter(Boolean);

        // 3. Return the last segment, or null/empty if there isn't one
        return segments.length ? segments.at(-1) : '/';
    } catch (error) {
        console.error("Invalid URL provided", error);
        return null;
    }
}

export function LogMsg(msg, ...objs) {
  try {
    let msgstr = "";

    if (msg instanceof Error) {
      msgstr = ErrorToJson(msg);
    } else if (typeof msg === "string" || msg instanceof String) {
      msgstr = msg;
    } else {
      try {
        msgstr = JSON.stringify(msg);
      } catch {}
    }

    logmsg_index++;
    let module_name = "client_pubnub.html";
    try {
        let tmodule_name = import.meta.url;

        if ( ! isNullOrEmpty(tmodule_name) ) {
            module_name = getLastEndpoint(tmodule_name);
        }

    } catch (ex) {

    }

    console.log("["+module_name+"]|[" + logmsg_index + "]|" + msgstr);

    if (objs && objs.length > 0) {
      objs.forEach((obj) => {
        console.log(obj);
      });
    }
  } catch (e) {
    console.log(e);
  }
}

export var logmsg = LogMsg;

export function createBuiltInCmd(cmdname) {
  let payload = {
    builtincmd: cmdname,
    source: "client_pubnub.html",
    destination: "pscdp.relay.ps1",
    cmdid: getRandomCode(8),
    ts: Date.now()
  };

  return payload;
}

/* PubNub Message Event:
    messageEvent.message
    actualChannel: "clientid_88992233_JS_client"
    channel: "clientid_88992233_JS_client"
    message: {msgstr: "ping -- 15:48:40.175"}
    publisher: "user-717"
    subscribedChannel: "clientid_88992233_JS_client"
    subscription: "clientid_88992233_JS_client"
    timetoken: "17900201204555720"
*/

LogMsg("--- client_pubnub.helper.js ---");
