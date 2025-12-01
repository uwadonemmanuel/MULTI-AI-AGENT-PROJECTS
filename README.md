# Multi-AI Agent Project

A powerful multi-agent AI system built with FastAPI and Streamlit that leverages Groq's high-performance language models and Tavily's web search capabilities. This project enables you to create customizable AI agents with optional web search functionality through an intuitive web interface.

## 🚀 Features

- **Multiple AI Models**: Support for various Groq production models including:
  - `llama-3.1-8b-instant` - Fast, cost-effective (560 t/s)
  - `llama-3.3-70b-versatile` - High-quality responses (280 t/s)
  - `openai/gpt-oss-120b` - Large OpenAI model (500 t/s)
  - `openai/gpt-oss-20b` - Fast OpenAI model (1000 t/s)
  - `meta-llama/llama-guard-4-12b` - Content moderation (1200 t/s)

- **Customizable System Prompts**: Define your AI agent's behavior and expertise through custom system prompts
- **Optional Web Search**: Enable Tavily web search integration for real-time information retrieval
- **Modern Web Interface**: Streamlit-based frontend for easy interaction
- **RESTful API**: FastAPI backend with comprehensive error handling
- **LangGraph Integration**: Built on LangGraph for advanced agent orchestration
- **Comprehensive Logging**: Detailed logging system for debugging and monitoring

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [API Documentation](#api-documentation)
- [Docker Deployment](#docker-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
- [AWS ECS Deployment](#aws-ecs-deployment)
- [Troubleshooting](#troubleshooting)
- [Technologies Used](#technologies-used)
- [Contributing](#contributing)

## 🔧 Prerequisites

- Python 3.10 or higher
- Groq API key ([Get one here](https://console.groq.com/))
- Tavily API key (optional, for web search) ([Get one here](https://app.tavily.com/sign-in))
- pip package manager

## 📦 Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd MULTI-AI-AGENT-PROJECTS
```

### 2. Create a Virtual Environment

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

Or install as a package:

```bash
pip install -e .
```

### 4. Set Up Environment Variables

Create a `.env` file in the root directory:

```env
GROQ_API_KEY=your_groq_api_key_here
TAVILY_API_KEY=your_tavily_api_key_here  # Optional, only needed if using web search
```

## ⚙️ Configuration

The application configuration is managed in `app/config/settings.py`. You can customize:

- **Allowed Models**: Modify `ALLOWED_MODEL_NAMES` to add or remove supported models
- **API Keys**: Set via environment variables in `.env` file

### Model Configuration

Current production models available:

| Model ID | Speed (t/s) | Input Cost | Output Cost | Context Window |
|----------|-------------|------------|-------------|----------------|
| `llama-3.1-8b-instant` | 560 | $0.05/1M | $0.08/1M | 131,072 |
| `llama-3.3-70b-versatile` | 280 | $0.59/1M | $0.79/1M | 131,072 |
| `openai/gpt-oss-120b` | 500 | $0.15/1M | $0.60/1M | 131,072 |
| `openai/gpt-oss-20b` | 1000 | $0.075/1M | $0.30/1M | 131,072 |
| `meta-llama/llama-guard-4-12b` | 1200 | $0.20/1M | $0.20/1M | 131,072 |

## 🎯 Usage

### Running the Application

Start both backend and frontend services:

```bash
python app/main.py
```

This will:
- Start the FastAPI backend on `http://127.0.0.1:9999`
- Start the Streamlit frontend (usually on `http://localhost:8501`)

### Using the Web Interface

1. Open your browser and navigate to the Streamlit interface (typically `http://localhost:8501`)
2. **Define your AI Agent**: Enter a system prompt to customize your agent's behavior (e.g., "You are a medical AI Agent specialized in cancer")
3. **Select Model**: Choose from the dropdown of available models
4. **Enable Web Search** (optional): Check the box if you want the agent to search the web for information
5. **Enter Query**: Type your question or request
6. **Ask Agent**: Click the "Ask Agent" button to get a response (e.g., "Can cancer be cured?")

### Example System Prompts

- **Medical Agent**: "You are a medical AI Agent specialized in cancer research and treatment. Provide evidence-based information."
- **Code Assistant**: "You are an expert Python developer. Write clean, efficient, and well-documented code."
- **Research Assistant**: "You are a research assistant. Analyze information critically and provide comprehensive summaries."

## 📁 Project Structure

```
MULTI-AI-AGENT-PROJECTS/
├── app/
│   ├── __init__.py
│   ├── main.py                 # Main entry point (starts backend & frontend)
│   ├── backend/
│   │   ├── __init__.py
│   │   └── api.py             # FastAPI backend with /chat endpoint
│   ├── core/
│   │   ├── __init__.py
│   │   └── ai_agent.py       # Core AI agent logic with LangGraph
│   ├── frontend/
│   │   ├── __init__.py
│   │   └── ui.py              # Streamlit web interface
│   ├── config/
│   │   ├── __init__.py
│   │   └── settings.py        # Configuration and settings
│   └── common/
│       ├── __init__.py
│       ├── logger.py          # Logging configuration
│       └── custom_exception.py # Custom exception handling
├── logs/                      # Application logs
├── requirements.txt           # Python dependencies
├── setup.py                   # Package setup
├── Dockerfile                 # Docker configuration
├── .env                       # Environment variables (create this)
└── README.md                  # This file
```

## 📡 API Documentation

### Endpoint: `POST /chat`

Send a chat request to the AI agent.

**Request Body:**
```json
{
  "model_name": "llama-3.3-70b-versatile",
  "system_prompt": "You are a helpful AI assistant.",
  "messages": ["What is the capital of France?"],
  "allow_search": false
}
```

**Response (200 OK):**
```json
{
  "response": "The capital of France is Paris."
}
```

**Error Responses:**

- **400 Bad Request**: Invalid model name or decommissioned model
  ```json
  {
    "detail": "Model 'llama3-70b-8192' has been decommissioned. Please use one of the supported models: llama-3.1-8b-instant, llama-3.3-70b-versatile, ..."
  }
  ```

- **500 Internal Server Error**: Server-side error during processing
  ```json
  {
    "detail": "Failed to get AI response | Error: ... | File: ... | Line: ..."
  }
  ```

### API Testing

You can test the API using curl:

```bash
curl -X POST "http://127.0.0.1:9999/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are a helpful assistant.",
    "messages": ["Hello, how are you?"],
    "allow_search": false
  }'
```

Or use the FastAPI interactive docs at `http://127.0.0.1:9999/docs` when the server is running.

## 🐳 Docker Deployment

### Build the Docker Image

```bash
docker build -t multi-ai-agent .
```

### Run the Container

```bash
docker run -p 8501:8501 -p 9999:9999 \
  -e GROQ_API_KEY=your_groq_api_key \
  -e TAVILY_API_KEY=your_tavily_api_key \
  multi-ai-agent
```

Or use a `.env` file:

```bash
docker run -p 8501:8501 -p 9999:9999 --env-file .env multi-ai-agent
```

**Note**: The application binds to `0.0.0.0` to be accessible from outside the container.

## 🔄 CI/CD Pipeline

This project includes a complete CI/CD pipeline using Jenkins, SonarQube, Docker, and AWS ECS.

### Pipeline Overview

1. **Source Control**: GitHub repository
2. **CI Server**: Jenkins (Docker-in-Docker)
3. **Code Quality**: SonarQube analysis
4. **Container Registry**: AWS ECR (Elastic Container Registry)
5. **Deployment**: AWS ECS Fargate

### Jenkins Pipeline Stages

The `Jenkinsfile` defines the following stages:

1. **Cloning Github repo to Jenkins**: Checks out the source code
2. **SonarQube Analysis**: Performs code quality and security analysis
3. **Build and Push Docker Image to ECR**: 
   - Builds Docker image
   - Tags with unique build number
   - Pushes to AWS ECR
4. **Deploy to ECS Fargate**:
   - Updates ECS task definition with new image
   - Deploys new revision to ECS service

### Jenkins Setup

1. **Start Jenkins Container**:
   ```bash
   cd custom_jenkins
   docker build -t jenkins-dind .
   docker run -d --name jenkins-dind \
     -p 8080:8080 \
     -v /var/run/docker.sock:/var/run/docker.sock \
     jenkins-dind
   ```

2. **Configure Jenkins**:
   - Access Jenkins at `http://localhost:8080`
   - Install required plugins: SonarQube Scanner, AWS ECR, Docker Pipeline
   - Configure SonarQube server
   - Add credentials:
     - GitHub token (`github-token`)
     - SonarQube token (`sonarqube-token`)
     - AWS credentials (`aws-credentials`)

3. **Create Pipeline Job**:
   - New Item → Pipeline
   - Configure SCM (GitHub repository)
   - Pipeline script from SCM → `Jenkinsfile`

### SonarQube Setup

1. **Start SonarQube Container**:
   ```bash
   docker run -d --name sonarqube-dind -p 9000:9000 sonarqube
   ```

2. **Access SonarQube**:
   - URL: `http://localhost:9000`
   - Default credentials: `admin/admin`
   - Create a project and generate a token

3. **Configure in Jenkins**:
   - Manage Jenkins → System Configuration → SonarQube Servers
   - Add SonarQube server with token

## ☁️ AWS ECS Deployment

### Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured
- ECS cluster created
- ECR repository created (or will be created automatically)
- ECS service and task definition configured

### Quick Deployment

The Jenkins pipeline automatically handles deployment, but you can also deploy manually:

#### 1. Build and Push to ECR

```bash
# Login to ECR
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.eu-north-1.amazonaws.com

# Build image
docker build -t multi-ai-agent:latest .

# Tag for ECR
docker tag multi-ai-agent:latest \
  <account-id>.dkr.ecr.eu-north-1.amazonaws.com/multi-ai-agent:latest

# Push to ECR
docker push <account-id>.dkr.ecr.eu-north-1.amazonaws.com/multi-ai-agent:latest
```

#### 2. Update ECS Service

```bash
# Update task definition with new image
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --force-new-deployment \
  --region eu-north-1
```

### Environment Variables in ECS

**Important**: The application requires environment variables in the ECS task definition:

- `GROQ_API_KEY`: Required for AI agent functionality
- `TAVILY_API_KEY`: Optional, required only if `allow_search=True`

#### Add Environment Variables

**Option 1: Using Script (Recommended)**
```bash
./add-env-vars-to-ecs.sh
```

**Option 2: Via AWS Console**
1. Go to ECS Task Definitions
2. Create new revision
3. Add environment variables in container definition
4. Update service to use new revision

**Option 3: Via AWS CLI**
See `FIX_MISSING_API_KEYS.md` for detailed instructions.

### Accessing the Deployed Application

After deployment, the application is accessible at:

- **Streamlit Frontend**: `http://<public-ip>:8501`
- **FastAPI Backend**: `http://<public-ip>:9999`

To find the public IP:
```bash
./find-ecs-public-ip.sh
```

Or check the ECS service in AWS Console → Tasks → Network → Public IP.

### Troubleshooting Scripts

The project includes several helpful scripts for troubleshooting:

| Script | Purpose |
|--------|---------|
| `check-task-status.sh` | Check why ECS tasks aren't running |
| `start-ecs-service.sh` | Start or update ECS service |
| `add-env-vars-to-ecs.sh` | Add environment variables to task definition |
| `test-connection.sh` | Test connectivity to deployed application |
| `view-logs.sh` | View CloudWatch logs |
| `find-ecs-service.sh` | Find ECS services in cluster |
| `find-ecs-cluster.sh` | List all ECS clusters |
| `update-cluster-service.sh` | Update cluster/service names in scripts |

### Common Deployment Issues

1. **No Running Tasks**
   - See: `FIX_NO_TASKS.md`
   - Run: `./check-task-status.sh`

2. **Missing API Keys**
   - See: `FIX_MISSING_API_KEYS.md`
   - Run: `./add-env-vars-to-ecs.sh`

3. **Connection Timeout**
   - See: `CONNECTION_TIMEOUT_FIX.md`
   - Verify security groups allow ports 8501 and 9999
   - Run: `./fix-security-group.sh`

4. **500 Internal Server Error**
   - See: `fix-500-error.md` or `common-500-fixes.md`
   - Check logs: `./view-logs.sh`

### Documentation

For detailed guides, see:

- `FIX_MISSING_API_KEYS.md` - How to add environment variables
- `FIX_NO_TASKS.md` - Troubleshooting no running tasks
- `CONNECTION_TIMEOUT_FIX.md` - Fix connection issues
- `ecs-troubleshooting-guide.md` - Comprehensive ECS troubleshooting
- `ecs-environment-variables-guide.md` - Environment variables guide

## 🛠️ Technologies Used

- **FastAPI**: Modern, fast web framework for building APIs
- **Streamlit**: Rapid web app development for the frontend
- **LangChain**: Framework for developing applications powered by language models
- **LangGraph**: Library for building stateful, multi-actor applications with LLMs
- **Groq**: High-performance AI inference platform
- **Tavily**: AI-powered search engine for real-time web information
- **Uvicorn**: ASGI server for running FastAPI
- **Pydantic**: Data validation using Python type annotations
- **Python-dotenv**: Environment variable management

## 🔍 Troubleshooting

### Local Development Issues

1. **Model Decommissioned Error**
   - **Solution**: Update to one of the supported models listed in `app/config/settings.py`

2. **Missing API Keys**
   - **Error**: `TAVILY_API_KEY is required when allow_search is True`
   - **Solution**: Add your API keys to the `.env` file

3. **Port Already in Use**
   - **Error**: `Address already in use`
   - **Solution**: Change ports in `app/main.py` or stop the process using the port

4. **Import Errors**
   - **Solution**: Ensure all dependencies are installed: `pip install -r requirements.txt`

5. **500 Internal Server Error**
   - Check logs in `logs/` directory for detailed error messages
   - Verify API keys are correct and have sufficient credits
   - Ensure the selected model is available and not decommissioned

### Viewing Logs

**Local Development:**
Logs are stored in the `logs/` directory with daily rotation:

```bash
tail -f logs/log_$(date +%Y-%m-%d).log
```

**AWS ECS (CloudWatch):**
```bash
./view-logs.sh
```

Or manually:
```bash
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1
```

### ECS Deployment Issues

For comprehensive ECS troubleshooting, see:

- **No Running Tasks**: `FIX_NO_TASKS.md` or run `./check-task-status.sh`
- **Missing Environment Variables**: `FIX_MISSING_API_KEYS.md` or run `./add-env-vars-to-ecs.sh`
- **Connection Timeout**: `CONNECTION_TIMEOUT_FIX.md` or run `./test-connection.sh`
- **500 Errors**: `fix-500-error.md` or `common-500-fixes.md`
- **General ECS Issues**: `ecs-troubleshooting-guide.md`

### Quick Troubleshooting Commands

```bash
# Check ECS task status
./check-task-status.sh

# Test application connectivity
./test-connection.sh

# View CloudWatch logs
./view-logs.sh

# Add missing environment variables
./add-env-vars-to-ecs.sh

# Start/restart ECS service
./start-ecs-service.sh

# Find ECS resources
./find-ecs-cluster.sh
./find-ecs-service.sh
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow PEP 8 style guidelines
- Add docstrings to new functions and classes
- Update this README for significant changes
- Test your changes thoroughly before submitting

## 📝 License

[Add your license information here]

## 👥 Authors

- **Sudhanshu** - Initial work

## 🙏 Acknowledgments

- Groq for providing high-performance AI inference
- Tavily for web search capabilities
- LangChain and LangGraph communities for excellent tooling
- FastAPI and Streamlit teams for amazing frameworks

## 📚 Additional Resources

### API Documentation
- [Groq Documentation](https://console.groq.com/docs)
- [Tavily Documentation](https://docs.tavily.com/)
- [LangChain Documentation](https://python.langchain.com/)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Streamlit Documentation](https://docs.streamlit.io/)

### AWS Resources
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS CloudWatch Logs](https://docs.aws.amazon.com/cloudwatch/latest/logs/)

### CI/CD Resources
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Docker Documentation](https://docs.docker.com/)

### Project Documentation

This repository includes comprehensive documentation:

- **Deployment Guides**:
  - `FIX_MISSING_API_KEYS.md` - Adding environment variables to ECS
  - `FIX_NO_TASKS.md` - Troubleshooting no running tasks
  - `CONNECTION_TIMEOUT_FIX.md` - Fixing connection issues
  - `ecs-troubleshooting-guide.md` - Complete ECS troubleshooting guide
  - `ecs-environment-variables-guide.md` - Environment variables guide

- **Configuration Guides**:
  - `ecs-container-config.md` - ECS container configuration
  - `aws-setup-best-practices.md` - AWS setup best practices

- **Troubleshooting Guides**:
  - `fix-500-error.md` - Fixing 500 errors
  - `common-500-fixes.md` - Common 500 error fixes
  - `FIND_CLUSTER_SERVICE.md` - Finding ECS cluster and service names

---

## 🚀 Quick Start Summary

### Local Development
```bash
# 1. Clone and setup
git clone <repository-url>
cd MULTI-AI-AGENT-PROJECTS
python -m venv venv
source venv/bin/activate
pip install -e .

# 2. Configure
echo "GROQ_API_KEY=your_key" > .env
echo "TAVILY_API_KEY=your_key" >> .env

# 3. Run
python app/main.py
```

### Docker Deployment
```bash
docker build -t multi-ai-agent .
docker run -p 8501:8501 -p 9999:9999 --env-file .env multi-ai-agent
```

### AWS ECS Deployment
```bash
# 1. Configure Jenkins pipeline (see CI/CD section)
# 2. Push to GitHub
# 3. Jenkins will automatically:
#    - Run SonarQube analysis
#    - Build and push to ECR
#    - Deploy to ECS

# Or deploy manually:
./add-env-vars-to-ecs.sh  # Add API keys
./start-ecs-service.sh    # Start service
./test-connection.sh       # Test deployment
```

---

**Note**: This project uses production models from Groq. Some models may be deprecated over time. Always check the [Groq deprecations page](https://console.groq.com/docs/deprecations) for the latest information.

