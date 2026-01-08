# Quick Start Guide

## Step 1: Install Dependencies

```bash
cd /Users/sami/Downloads/vscode-download/Aicono/testLoxoneConnection
npm install
```

## Step 2: Create Environment File

Create a `.env` file in the project directory:

```bash
touch .env
```

## Step 3: Configure Connection

Edit the `.env` file with your Loxone Miniserver details:

```env
LOXONE_IP=192.168.1.77
LOXONE_PORT=
PROTOCOL=wss
LOXONE_USER=admin
LOXONE_PASS=your_password_here
CLIENT_UUID=
CLIENT_INFO=AiconoIntegration
PERMISSION=2
```

### Required Information to Collect from Client:

1. **LOXONE_IP** - Miniserver IP or hostname
2. **LOXONE_PORT** - Port (leave empty for default)
3. **PROTOCOL** - `wss` (secure) or `ws` (non-secure)
4. **LOXONE_USER** - Username
5. **LOXONE_PASS** - Password
6. **CLIENT_UUID** - Optional, auto-generated if empty
7. **CLIENT_INFO** - Description of integration
8. **PERMISSION** - `2` (Web) or `4` (App)

## Step 4: Run the Application

```bash
npm start
```

## Expected Output

You should see:
```
============================================================
Loxone Miniserver Connection Demo
============================================================
Configuration:
  IP: 192.168.1.77
  Port: default
  Protocol: wss
  User: admin
  Client UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
============================================================

[CONNECT] Connecting to: wss://192.168.1.77/ws/rfc6455
[CONNECT] ✓ WebSocket connection established
[AUTH] Requesting key and salt...
[RECEIVE] { ... }
[AUTH] Received key and salt. Algorithm: SHA1
...
[AUTH] ✓ Authentication successful!
[INFO] Fetching structure file...
[INFO] Structure file received
[INFO] Structure file saved to: ./LoxAPP3.json
[INFO] Enabling live status updates...
[INFO] ✓ Demo app is fully connected and ready!
[INFO] Waiting for live events...
```

## Troubleshooting

### Connection Failed
- Check IP address and port
- Verify network connectivity: `ping <LOXONE_IP>`
- Ensure Miniserver is accessible

### Authentication Failed
- Verify username and password
- Check user permissions
- Ensure protocol matches Miniserver generation

### No Events
- Verify devices are changing state
- Check that `enablebinstatusupdate` was sent
- Ensure connection is still active

## Next Steps

1. Review the saved `LoxAPP3.json` file to understand the structure
2. Map UUIDs to device names for better logging
3. Integrate with your main application
4. Store events in your database
5. Implement control commands

