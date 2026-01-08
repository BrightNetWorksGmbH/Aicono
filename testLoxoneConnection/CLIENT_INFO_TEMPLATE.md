# Client Information Collection Template

Use this template when collecting information from clients for Loxone Miniserver integration.

## Client Details

**Client Name:** _____________________________  
**Date:** _____________________________  
**Contact Person:** _____________________________  
**Contact Email:** _____________________________  

---

## Loxone Miniserver Configuration

### 1. Network Information

**Miniserver IP Address or Hostname:**
- [ ] IP Address: `_____________________`
- [ ] OR Hostname: `_____________________`
- **Question to ask:** "What is the IP address or hostname of your Loxone Miniserver?"

**Port Number:**
- [ ] Port: `_____________________` (Leave blank if using default: 443 for secure, 80 for non-secure)
- **Question to ask:** "What port does your Loxone Miniserver use? (Most installations use default ports)"

**Protocol/Generation:**
- [ ] Generation 1 (HTTP/WS) - Use `ws://`
- [ ] Generation 2 (HTTPS/WSS) - Use `wss://` ⭐ **Recommended**
- **Question to ask:** "What generation is your Loxone Miniserver? (1 or 2, or do you use secure connections?)"

### 2. Authentication Credentials

**Username:**
- [ ] Username: `_____________________`
- **Question to ask:** "What username should we use to connect to your Loxone Miniserver?"

**Password:**
- [ ] Password: `_____________________`
- **Question to ask:** "What is the password for the Loxone Miniserver user account?"
- ⚠️ **Security Note:** Store this securely, never in plain text in code

**Permission Level:**
- [ ] Web Access (Permission: 2)
- [ ] App Access (Permission: 4)
- **Question to ask:** "What permission level should we use? (2 for Web access, 4 for App access)"

### 3. Client Identification (Optional)

**Client UUID:**
- [ ] UUID: `_____________________` (Leave blank to auto-generate)
- **Question to ask:** "Do you have a specific client UUID for this integration, or should we generate one?"

**Client Description:**
- [ ] Description: `_____________________` (e.g., "Aicono Energy Management")
- **Question to ask:** "What should we call this integration in the Loxone system?"

---

## Verification Checklist

Before starting integration, verify:

- [ ] Can ping the Miniserver IP address
- [ ] Network connectivity confirmed
- [ ] Credentials tested and working
- [ ] Protocol (ws/wss) confirmed
- [ ] Port number confirmed (if non-standard)
- [ ] Permission level appropriate for required operations

---

## Notes

**Additional Information:**
```
_____________________________________________________________
_____________________________________________________________
_____________________________________________________________
```

**Special Requirements:**
```
_____________________________________________________________
_____________________________________________________________
```

---

## Quick Setup Commands

After collecting information, update the `.env` file:

```bash
LOXONE_IP=<collected_ip>
LOXONE_PORT=<collected_port_or_blank>
PROTOCOL=<wss_or_ws>
LOXONE_USER=<collected_username>
LOXONE_PASS=<collected_password>
CLIENT_UUID=<collected_uuid_or_blank>
CLIENT_INFO=<collected_description>
PERMISSION=<2_or_4>
```

Then test the connection:
```bash
npm install
npm start
```

