# IP Address Updated to 13.60.97.107

## ✅ All Scripts Updated

All scripts and documentation now use the new IP address: **13.60.97.107**

## Your Service URLs

### Streamlit Frontend
```
http://13.60.97.107:8501
```
**Status:** ✅ Responding (HTTP 200)

### FastAPI Backend
```
http://13.60.97.107:9999
```
**Status:** ⚠️ Check connectivity

### API Documentation
```
http://13.60.97.107:9999/docs
```

### Chat Endpoint
```
http://13.60.97.107:9999/chat
```

## Quick Test

Run the test script:
```bash
./test-connection.sh
```

Or test manually:
```bash
# Test Streamlit
curl http://13.60.97.107:8501

# Test FastAPI
curl http://13.60.97.107:9999/docs

# Test API
curl -X POST http://13.60.97.107:9999/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are helpful.",
    "messages": ["Hello"],
    "allow_search": false
  }'
```

## Files Updated

- ✅ `troubleshoot-connection.sh` - Uses new IP
- ✅ `diagnose-ecs.sh` - Uses new IP
- ✅ `fix-security-group.sh` - Uses new IP
- ✅ `test-connection.sh` - New test script with new IP
- ✅ All documentation files updated

## Next Steps

1. **Test connection:**
   ```bash
   ./test-connection.sh
   ```

2. **If port 9999 not accessible:**
   ```bash
   ./fix-security-group.sh
   ```

3. **If issues persist:**
   ```bash
   ./troubleshoot-connection.sh
   ```

## Current Status

Based on test results:
- ✅ **Streamlit (8501)**: Working - HTTP 200
- ⚠️ **FastAPI (9999)**: May need security group rule

The Streamlit UI should be accessible at: **http://13.60.97.107:8501**

