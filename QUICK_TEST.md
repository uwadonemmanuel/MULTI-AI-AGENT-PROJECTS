# Quick Test Guide - New IP Address

## Your Service URLs

**New IP Address:** `13.60.97.107`

### Streamlit UI (Frontend)
```
http://13.60.97.107:8501
```

### FastAPI Backend
```
http://13.60.97.107:9999
```

### API Documentation
```
http://13.60.97.107:9999/docs
```

### Chat Endpoint
```
http://13.60.97.107:9999/chat
```

## Quick Test

### Option 1: Use Test Script
```bash
./test-connection.sh
```

This will test:
- ✅ Port 8501 connectivity
- ✅ Port 9999 connectivity
- ✅ Streamlit response
- ✅ FastAPI response
- ✅ /chat endpoint

### Option 2: Manual Tests

**Test Streamlit:**
```bash
curl http://13.60.97.107:8501
# Or open in browser: http://13.60.97.107:8501
```

**Test FastAPI:**
```bash
curl http://13.60.97.107:9999/docs
# Or open in browser: http://13.60.97.107:9999/docs
```

**Test Chat API:**
```bash
curl -X POST http://13.60.97.107:9999/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are a helpful assistant.",
    "messages": ["Hello"],
    "allow_search": false
  }'
```

## Troubleshooting

If connection fails:

1. **Run diagnostic:**
   ```bash
   ./troubleshoot-connection.sh
   ```

2. **Fix security group:**
   ```bash
   ./fix-security-group.sh
   ```

3. **Check logs:**
   ```bash
   ./view-logs.sh
   ```

## Notes

- **Port 8501**: Streamlit frontend
- **Port 9999**: FastAPI backend
- Both services should be accessible after:
  - Code is deployed (binding to 0.0.0.0)
  - Security group allows ports 8501 and 9999
  - Task is running


