#!/bin/bash
# Quick test script for the new IP address

export PUBLIC_IP=13.60.97.107
export PORT_8501=8501
export PORT_9999=9999

echo "=========================================="
echo "Testing Connection to ECS Service"
echo "=========================================="
echo "IP Address: $PUBLIC_IP"
echo ""

# Test port 8501 (Streamlit)
echo "1. Testing Streamlit (port $PORT_8501)..."
echo "----------------------------------------"
if command -v nc &> /dev/null; then
  if timeout 5 nc -zv $PUBLIC_IP $PORT_8501 2>&1 | grep -q "succeeded"; then
    echo "   ✅ Port $PORT_8501 is open"
  else
    echo "   ❌ Port $PORT_8501 is NOT accessible"
  fi
else
  echo "   ⚠️  'nc' not installed, skipping port test"
fi

HTTP_CODE_8501=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$PUBLIC_IP:$PORT_8501 2>/dev/null || echo "000")
if [ "$HTTP_CODE_8501" = "200" ] || [ "$HTTP_CODE_8501" = "302" ] || [ "$HTTP_CODE_8501" = "307" ]; then
  echo "   ✅ HTTP $HTTP_CODE_8501 - Streamlit is responding"
  echo "   🌐 Open in browser: http://$PUBLIC_IP:$PORT_8501"
elif [ "$HTTP_CODE_8501" = "000" ]; then
  echo "   ❌ Connection failed - Check security group and application status"
else
  echo "   ⚠️  HTTP $HTTP_CODE_8501 - Service responding but may have issues"
fi

# Test port 9999 (FastAPI)
echo ""
echo "2. Testing FastAPI (port $PORT_9999)..."
echo "----------------------------------------"
if command -v nc &> /dev/null; then
  if timeout 5 nc -zv $PUBLIC_IP $PORT_9999 2>&1 | grep -q "succeeded"; then
    echo "   ✅ Port $PORT_9999 is open"
  else
    echo "   ❌ Port $PORT_9999 is NOT accessible"
  fi
else
  echo "   ⚠️  'nc' not installed, skipping port test"
fi

HTTP_CODE_9999=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$PUBLIC_IP:$PORT_9999/docs 2>/dev/null || echo "000")
if [ "$HTTP_CODE_9999" = "200" ]; then
  echo "   ✅ HTTP $HTTP_CODE_9999 - FastAPI is responding"
  echo "   🌐 API Docs: http://$PUBLIC_IP:$PORT_9999/docs"
elif [ "$HTTP_CODE_9999" = "000" ]; then
  echo "   ❌ Connection failed - Check security group and application status"
else
  echo "   ⚠️  HTTP $HTTP_CODE_9999 - Service responding but may have issues"
fi

# Test API endpoint
echo ""
echo "3. Testing /chat endpoint..."
echo "----------------------------------------"
API_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 -X POST http://$PUBLIC_IP:$PORT_9999/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are helpful.",
    "messages": ["Hello"],
    "allow_search": false
  }' 2>/dev/null)

HTTP_CODE=$(echo "$API_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$API_RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "200" ]; then
  echo "   ✅ API is working! HTTP $HTTP_CODE"
  echo "   Response: $(echo $BODY | head -c 100)..."
elif [ "$HTTP_CODE" = "500" ]; then
  echo "   ⚠️  HTTP $HTTP_CODE - Internal Server Error"
  echo "   Check logs for full error: ./view-logs.sh"
  echo "   Error details: $BODY"
elif [ "$HTTP_CODE" = "000" ]; then
  echo "   ❌ Connection failed"
else
  echo "   ⚠️  HTTP $HTTP_CODE"
  echo "   Response: $BODY"
fi

echo ""
echo "=========================================="
echo "Quick Links:"
echo "=========================================="
echo "Streamlit UI:  http://$PUBLIC_IP:$PORT_8501"
echo "FastAPI Docs:  http://$PUBLIC_IP:$PORT_9999/docs"
echo "API Endpoint:  http://$PUBLIC_IP:$PORT_9999/chat"
echo ""
echo "If connection fails, run:"
echo "  ./troubleshoot-connection.sh"
echo "  ./fix-security-group.sh"

