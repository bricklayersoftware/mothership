const helper = window.helper;

helper.logmsg('--- client_pubnub.ui.js ---');

export function updateTargetId() {
    let targetId = getTargetId()

    document.getElementById('targetId').value = targetId;
    document.getElementById('targetIdList').value = targetId;
    document.getElementById('targetIdText').value = targetId;
}

export function getTargetId() {
    let telem = document.getElementById('targetId');
    let targetId = telem.value;

    if (!targetId || !targetId.trim()) {
        targetId = document.getElementById('targetIdText').value;
    }

    if (!targetId || !targetId.trim()) {
        targetId = document.getElementById('targetIdList').value;
    }

    return targetId;
}

export function navigateDebug() {
    let elem = document.getElementById('devtoolsFrontendUrl');
    let fullUrl = elem.value;
    const urlObj = new URL(fullUrl);
    const relativeUrl = urlObj.pathname + urlObj.search + urlObj.hash;

    document.getElementById('processCDPUrl').value = 'https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/processcdp' + relativeUrl;
}

export function refreshMessages(messagelist) {

    if (!messagelist || messagelist.length == 0) {
        helper.logmsg("messages list empty or null");
        return;
    }

    clearTable('messagesTable');

    let opts = getOpts();

    let tmessagelist = [];
    for (let i = 0; i < messagelist.length; i++) {
        let msg = messagelist[i];

        let addmsg = showMessage(msg, opts);

        if (addmsg) {
            tmessagelist.push(msg);
        }

    }

    for (let i = 0; i < tmessagelist.length; i++) {
        let msg = tmessagelist[i];

        addMessage(msg);
    }
}

export function isNullOrWhitespace(value) {
    return (
        value === null ||
        value === undefined ||
        typeof value !== "string" ||
        value.trim().length === 0
    );
}

let scriptfname = 'client_pubnub.html';

export function showMessage(msg, opts) {
    let addmsg = false;

    if (opts.broadcastin && msg.message.destination == 'BROADCAST' && msg.message.source != scriptfname) {
        addmsg = true;
    }
    else if (opts.broadcastout && msg.message.destination == 'BROADCAST' && msg.message.source == scriptfname) {
        addmsg = true;
    }
    else if (opts.inbound && msg.message.destination == scriptfname) {
        addmsg = true;
    } else if (opts.outbound && msg.message.source == scriptfname) {
        addmsg = true;
    }
    else if (opts.cdprelay && msg.message.builtincmd == 'ProcessCDP') {
        addmsg = true;
    }

    let source = opts.source;
    let destination = opts.destination;

    if (!isNullOrWhitespace(source)) {
        if (source != msg.message.source) {
            addmsg = false;
        }
    }

    if (!isNullOrWhitespace(destination)) {
        if (destination != msg.message.destination) {
            addmsg = false;
        }
    }

    return addmsg;
}

export function addMessage(message) {
    let opts = getOpts();

    if (!showMessage(message, opts)) {
        return;
    }

    const table = document.getElementById("messagesTable");

    addItem(table, message);
}

export function refreshTargets(targets) {
    refreshTargetsTable(targets);
    refreshTargetIdList(targets);
}

export function addTarget(target) {

    const table = document.getElementById("targetsList");
    const tbody = table.createTBody();

    let insertrow = (key, item) => {
        let newRow = tbody.insertRow(-1);

        let newCell = newRow.insertCell(0);
        newCell.textContent = key;

        newCell = newRow.insertCell(1);
        let txt = JSON.stringify(item, null, 2);

        if (txt.startsWith('"') && txt.endsWith('"')) {
            txt = txt.slice(1, -1);
        }

        newCell.textContent = txt;
    };

    let keys = Object.getOwnPropertyNames(target);

    let objStack = [];

    objStack.push({
        name: 'ROOT',
        payload: target,
        path: ''
    });

    while (objStack.length > 0) {
        let mobj = objStack.pop()
        let objName = mobj['name'];
        let obj = mobj['payload'];
        let path = mobj['path'];

        insertrow(path + '.' + objName, '[---------]');

        if (obj == null) {
            console.log('[8JH4] error');
        }

        let keys = Object.getOwnPropertyNames(obj);

        for (let i = 0; i < keys.length; i++) {
            let key = keys[i];
            let item = obj[key];

            if (item != null && typeof item == 'object') {
                objStack.push({
                    name: '[' + key + ']',
                    payload: item,
                    path: path + '.' + objName
                });
                continue;
            }

            insertrow(key, item);
        }

    }

    newRow = tbody.insertRow(-1);
    newCell = newRow.insertCell();
    newCell.textContent = '-------------------- ';
    newCell.style.backgroundColor = "grey";
    newCell.colSpan = 2;
}

export function refreshTargetsTable(targets) {

    clearTable('targetsList');

    for (let i = 0; i < targets.length; i++) {
        let target = targets[i];

        addTarget(target);
    }

}

export function addCommand(table, command) {

    // const table = document.getElementById("commandsList");
    const tbody = table.createTBody();

    let insertrow = (key, item, bgcolor) => {
        let newRow = tbody.insertRow(-1);

        if (bgcolor) {
            newRow.style.backgroundColor = bgcolor;
        }

        let newCell = newRow.insertCell(0);
        newCell.textContent = key;

        newCell = newRow.insertCell(1);
        let txt = JSON.stringify(item, null, 2);

        if (txt.startsWith('"') && txt.endsWith('"')) {
            txt = txt.slice(1, -1);
        }

        newCell.textContent = txt;
    };

    let objStack = [];

    objStack.push({
        name: 'ROOT',
        payload: command,
        path: '',
        bgcolor: "#696969"
    });

    while (objStack.length > 0) {
        let mobj = objStack.pop()
        let objName = mobj['name'];
        let obj = mobj['payload'];
        let path = mobj['path'];
        let bgcolor = mobj['bgcolor'];

        insertrow(path + '.' + objName, '[---------]', bgcolor);

        let keys = Object.getOwnPropertyNames(obj);

        for (let i = 0; i < keys.length; i++) {
            let key = keys[i];
            let item = obj[key];

            if (item != null && typeof item == 'object') {
                objStack.push({
                    name: '[' + key + ']',
                    payload: item,
                    path: path + '.' + objName,
                    bgcolor: "#FFA500"
                });
                continue;
            }

            insertrow(key, item);
        }

    }

}

export function refreshCommandsTable(commands) {
    helper.LogMsg('refreshCommandsTable');

    const table = document.getElementById("commandsList");
    const existingTbodys = table.querySelectorAll("tbody");
    existingTbodys.forEach(tbody => tbody.remove());

    commands.forEach(command => {
        addCommand(table, command);
    });

}

export function refreshTargetIdList(targets) {
    console.log('refreshTargetIdList');

    let dropdown = document.getElementById('targetIdList');
    dropdown.options.length = 0;

    targets.forEach(target => {
        console.log(target);

        const newOption = document.createElement("option");

        newOption.text = target.targetId;
        newOption.value = target.targetId;

        dropdown.add(newOption);
    });

    document.getElementById('targetIdList').options[0].selected = true;

    handleTargetIdChange(document.getElementById('targetIdList'));
}

export function handleTargetIdChange(elem) {
    console.log('handleTargetIdChange: ' + elem.value);

    let targetid = elem.value;

    let telem = document.getElementById('targetId');
    telem.value = elem.value;

    telem = document.getElementById('targetIdText');
    telem.value = elem.value;

    telem = document.getElementById('targetIdList');
    telem.value = elem.value;

    let target = targetslist.find(target => {
        return target.targetId == targetid;
    });

    let sessionid = target.sessionId;
    let title = target.title;
    let url = target.url;
    let debugurl = target.devtoolsFrontendUrl;

    telem = document.getElementById('targetSessionId');
    telem.innerText = sessionid;

    telem = document.getElementById('targetTitle');
    telem.innerText = title;

    telem = document.getElementById('targetURL');
    telem.innerText = url;

    telem = document.getElementById('targetDebugURL');
    telem.innerText = debugurl;
}

export function handleCmdnameChange(elem) {
    // console.log('handleCmdnameChange');
    console.log('handleCmdnameChange: ' + elem.value);
}

export function addResult(result) {
    const table = document.getElementById("resultsList");
    const tbody = table.createTBody();

    let insertrow = (key, item, bgcolor) => {
        let newRow = tbody.insertRow(-1);

        if (bgcolor) {
            newRow.style.backgroundColor = bgcolor;
        }

        let newCell = newRow.insertCell(0);
        newCell.textContent = key;

        newCell = newRow.insertCell(1);
        let txt = JSON.stringify(item, null, 2);

        if (txt.startsWith('"') && txt.endsWith('"')) {
            txt = txt.slice(1, -1);
        }

        newCell.textContent = txt;
    };

    let objStack = [];

    objStack.push({
        name: 'ROOT',
        payload: result,
        path: '',
        bgcolor: "#696969"
    });

    while (objStack.length > 0) {
        let mobj = objStack.pop()
        let objName = mobj['name'];
        let obj = mobj['payload'];
        let path = mobj['path'];
        let bgcolor = mobj['bgcolor'];

        insertrow(path + '.' + objName, '[---------]', bgcolor);

        let keys = Object.getOwnPropertyNames(obj);

        for (let i = 0; i < keys.length; i++) {
            let key = keys[i];
            let item = obj[key];

            if (item != null && typeof item == 'object') {
                objStack.push({
                    name: '[' + key + ']',
                    payload: item,
                    path: path + '.' + objName,
                    bgcolor: "#FFA500"
                });
                continue;
            }

            insertrow(key, item);
        }

    }

}

export function collapseTable(tableid) {
    let telem = document.getElementById(tableid);
    telem.classList.add("collapsed");
}

export function expandTable(tableid) {
    let telem = document.getElementById(tableid);
    telem.classList.remove("collapsed");
}

export function clearTable(tableid) {
    const table = document.getElementById(tableid);

    table.querySelectorAll('tbody').forEach(tbody => tbody.remove());
}

export function refreshTable(tableid, items) {

    clearTable(tableid);

    const table = document.getElementById(tableid);

    if (!Array.isArray(items)) {
        items = [items];
    }

    items.forEach(item => {
        addItem(table, item);
    });

    // iterate through table rows,
    // convert row with backendNodeId
    // to link DOM.describeNode

}

export function addItem(table, result) {
    const tbody = table.createTBody();
    table.prepend(tbody);

    let insertrow = (key, item, bgcolor) => {
        let newRow = tbody.insertRow(-1);

        if (bgcolor) {
            newRow.style.backgroundColor = bgcolor;
        }

        let newCell = newRow.insertCell(0);
        newCell.textContent = key;

        newCell = newRow.insertCell(1);
        let txt = JSON.stringify(item, null, 2);

        if (isNullOrWhitespace(txt)) { // anchor
            txt = 'NULL';
        }

        if (txt.startsWith('"') && txt.endsWith('"')) {
            txt = txt.slice(1, -1);
        }

        newCell.textContent = txt;
    };

    let objStack = [];

    objStack.push({
        name: 'ROOT',
        payload: result,
        path: '',
        bgcolor: "#696969"
    }); // 696969 --> grey

    while (objStack.length > 0) {
        let mobj = objStack.pop()
        let objName = mobj['name'];
        let obj = mobj['payload'];
        let path = mobj['path'];
        let bgcolor = mobj['bgcolor'];

        insertrow(path + '.' + objName, '[---------]', bgcolor);

        let keys = Object.getOwnPropertyNames(obj);

        for (let i = 0; i < keys.length; i++) {
            let key = keys[i];
            let item = obj[key];

            if (item && typeof item == 'object') {
                objStack.push({
                    name: '[' + key + ']',
                    payload: item,
                    path: path + '.' + objName,
                    bgcolor: "#FFA500"
                });
            } else {
                insertrow(key, item);
            }
        }

    }
}

export function getOpts() {
    let inbound = document.getElementById('messagesInbound');
    let outbound = document.getElementById('messagesOutbound');

    let broadcastOut = document.getElementById('messagesOutBroadcastOpt');
    let broadcastIn = document.getElementById('messagesInBroadcastOpt');

    let cdprelay = document.getElementById('messagesCDPRelay');
    let source = document.getElementById('messagesSource');
    let destination = document.getElementById('messagesDestination');

    let opts = {
        "inbound": inbound.checked,
        "outbound": outbound.checked,
        "broadcastin": broadcastIn.checked,
        "broadcastout": broadcastOut.checked,
        "cdprelay": cdprelay.checked,
        "source": source,
        "destination": destination,
        "logToConsole": document.getElementById('logToConsoleOpt').checked,
        "sendPBBroadcast": document.getElementById('sendPBBroadcastOpt').checked,
        "logPBBroadcast":document.getElementById('logPBBroadcastOpt').checked
    };

    return opts;
}

export function toggleMessages(messagelist) {
    let opts = getOpts();

    refreshMessages(messagelist, opts);
}

export function insertJSCode(jscodename) {
    let jscodestr = jscodelist[jscodename];

    let elem = document.getElementById('evaluateCmd');
    elem.value = jscodestr;
}