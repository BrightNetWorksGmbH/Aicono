# Loxone Miniserver Connection Demo

This is a Node.js demo application for connecting to a Loxone Miniserver. It demonstrates:
- WebSocket connection establishment
- Token-based authentication
- Downloading and caching the structure file (LoxAPP3.json)
- Real-time binary event handling

## Prerequisites

- Node.js (v14 or higher)
- Access to a Loxone Miniserver
- Network connectivity to the Miniserver

## Installation

1. Install dependencies:
```bash
npm install
```

2. Copy the example environment file:
```bash
cp .env.example .env
```

3. Edit `.env` with your Loxone Miniserver credentials and settings.

## Configuration

Edit the `.env` file with the following information that you need to collect from your client:

### Required Information from Client:

1. **LOXONE_IP** - The IP address or domain name of the Loxone Miniserver
   - Example: `192.168.1.77` or `miniserver.example.com`
   - **Ask client:** "What is the IP address or hostname of your Loxone Miniserver?"

2. **LOXONE_PORT** - The port number (optional, defaults to 443 for WSS or 80 for WS)
   - Leave empty to use default ports
   - **Ask client:** "What port does your Loxone Miniserver use? (Leave empty for default: 443 for secure, 80 for non-secure)"

3. **PROTOCOL** - Connection protocol
   - `wss` for Generation 2 Miniserver (HTTPS/WSS) - **Recommended**
   - `ws` for Generation 1 Miniserver (HTTP/WS)
   - **Ask client:** "What generation is your Loxone Miniserver? (1 or 2, or use 'wss' for secure, 'ws' for non-secure)"

4. **LOXONE_USER** - Username for authentication
   - Example: `admin`
   - **Ask client:** "What username should we use to connect to your Loxone Miniserver?"

5. **LOXONE_PASS** - Password for authentication
   - **Ask client:** "What is the password for the Loxone Miniserver user account?"

6. **CLIENT_UUID** - Unique identifier for this client installation (optional, auto-generated if not provided)
   - Should be a unique UUID for each client
   - **Ask client:** "Do you have a specific client UUID, or should we generate one?"

7. **CLIENT_INFO** - Description of this client (optional)
   - Example: `NodeDemoApp` or `AiconoIntegration`
   - **Ask client:** "What should we call this integration? (e.g., 'Aicono Energy Management')"

8. **PERMISSION** - Access permission level (optional, default: 2)
   - `2` = Web access
   - `4` = App access
   - **Ask client:** "What permission level should we use? (2 for Web, 4 for App)"

### Optional Configuration:

- **KEEPALIVE_INTERVAL** - How often to send keepalive messages (default: 300000ms = 5 minutes)
- **STRUCTURE_FILE_PATH** - Where to save the structure file (default: `./LoxAPP3.json`)

## Usage

Run the application:
```bash
npm start
```

Or in development mode with auto-reload:
```bash
npm run dev
```

## What the Application Does

1. **Connects** to the Loxone Miniserver via WebSocket
2. **Authenticates** using the token-based authentication flow:
   - Requests key and salt
   - Hashes credentials
   - Requests JWT token
   - Authenticates with token
3. **Downloads** the structure file (LoxAPP3.json) and saves it locally
4. **Enables** live status updates
5. **Listens** for real-time binary events (value states, text states, etc.)
6. **Maintains** connection with periodic keepalive messages

## Output

The application will:
- Log all connection steps
- Save the structure file to `LoxAPP3.json` (or your configured path)
- Display real-time value updates as they occur
- Show UUIDs and values for state changes

## Structure File

The `LoxAPP3.json` file contains the complete structure of the Loxone installation, including:
- All devices and their UUIDs
- Human-readable names
- Categories and rooms
- Control types

This file is essential for mapping the UUIDs received in binary events to actual device names.

## Binary Events

The application handles several types of binary events:
- **Identifier 0**: Text messages (JSON)
- **Identifier 1**: Binary files
- **Identifier 2**: Value states (lights, temperatures, sensors, etc.)
- **Identifier 3**: Text states (song titles, etc.)

Value states are parsed as:
- 16 bytes: UUID
- 8 bytes: Double precision float value

## Troubleshooting

### Connection Issues
- Verify the IP address and port are correct
- Check network connectivity (ping the Miniserver)
- Ensure the Miniserver is accessible from your network
- For self-signed certificates, the app uses `rejectUnauthorized: false` (only for testing)

### Authentication Issues
- Verify username and password are correct
- Check that the user has the required permissions
- Ensure the Miniserver supports the selected protocol (wss/ws)

### No Events Received
- Verify that `jdev/sps/enablebinstatusupdate` was sent successfully
- Check that devices are actually changing state
- Ensure the connection is still active (check keepalive)

## Security Notes

- **Never commit** the `.env` file to version control
- The `.env.example` file is safe to commit (no real credentials)
- For production, use environment variables or a secure configuration management system
- The `rejectUnauthorized: false` option is only for testing with self-signed certificates

## Next Steps

After successfully connecting:
1. Parse the structure file to build a device mapping
2. Implement business logic to handle specific device types
3. Store events in your database
4. Build APIs to expose Loxone data to your application
5. Implement control commands to send commands back to the Miniserver

## Client Information Checklist

When onboarding a new client, collect:

- [ ] Miniserver IP address or hostname
- [ ] Port number (if non-standard)
- [ ] Protocol (wss/ws or Generation 1/2)
- [ ] Username
- [ ] Password
- [ ] Permission level (2 or 4)
- [ ] Client UUID (optional)
- [ ] Client description/name

## License

ISC

