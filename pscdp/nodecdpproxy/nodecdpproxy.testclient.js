let scriptfname = 'nodecdpproxy.testclient.js';

// Replace with your WebSocket server URL (ws:// or wss://)
const socket = new WebSocket('ws://localhost:8123');

// 1. Connection opened
socket.addEventListener('open', () => {
  console.log('Connected to server');

  // Send a plain text message
  socket.send('hello from nodecdpproxy.testclient.js');

  // Send a JSON payload
  socket.send(JSON.stringify({ event: 'ping', timestamp: Date.now() }));
});

// 2. Listen for incoming messages
socket.addEventListener('message', (event) => {
  console.log('Received:', event.data);
});

// 3. Handle connection close
socket.addEventListener('close', (event) => {
  console.log(`Disconnected (Code: ${event.code}, Reason: ${event.reason})`);
});

// 4. Handle errors
socket.addEventListener('error', (error) => {
  console.error('WebSocket error:', error);
});
