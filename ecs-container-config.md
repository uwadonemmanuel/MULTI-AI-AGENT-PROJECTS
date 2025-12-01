# ECS Task Definition - Container Configuration

## Container Details

### 1. Name
```
multi-ai-agent
```

### 2. Essential Container
```
✅ Yes (checked)
```

### 3. Image URI
```
844810703328.dkr.ecr.eu-north-1.amazonaws.com/multi-ai-agent:latest
```

**Or use Browse ECR images:**
- Region: `eu-north-1`
- Repository: `multi-ai-agent`
- Image tag: `latest`

### 4. Private Registry Authentication
```
Leave as default (no authentication needed for ECR in same account)
```

### 5. Port Mappings

Add **TWO** port mappings:

#### Port Mapping 1 (Streamlit)
- **Container port:** `8501`
- **Protocol:** `TCP`
- **Host port:** (leave empty or `8501`)

#### Port Mapping 2 (FastAPI)
- **Container port:** `9999`
- **Protocol:** `TCP`
- **Host port:** (leave empty or `9999`)

## Additional Configuration (Optional)

### Environment Variables
If needed, you can add:
- `GROQ_API_KEY` (if not using Secrets Manager)
- `TAVILY_API_KEY` (if not using Secrets Manager)

### Health Check (Recommended)
- **Command:** `CMD-SHELL,curl -f http://localhost:8501/_stcore/health || exit 1`
- **Interval:** `30`
- **Timeout:** `5`
- **Retries:** `3`
- **Start period:** `60`

## Notes

- Your Dockerfile exposes ports `8501` (Streamlit) and `9999` (FastAPI)
- The container runs both services simultaneously
- Make sure your ECS service security group allows inbound traffic on ports 8501 and 9999




