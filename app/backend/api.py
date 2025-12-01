from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import traceback
import os
from app.core.ai_agent import get_response_from_ai_agents
from app.config.settings import settings
from app.common.logger import get_logger, log_full_traceback
from app.common.custom_exception import CustomException

try:
    from groq import BadRequestError
except ImportError:
    BadRequestError = None

logger = get_logger(__name__)

app = FastAPI(title="MULTI AI AGENT")

# Enable debug mode if in development
DEBUG_MODE = os.getenv("DEBUG", "false").lower() == "true"

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class RequestState(BaseModel):
    model_name:str
    system_prompt:str
    messages:List[str]
    allow_search: bool

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler to catch all unhandled exceptions"""
    error_details = log_full_traceback(logger, exc, f"Unhandled exception in {request.url.path}: ")
    
    if DEBUG_MODE:
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal Server Error",
                "error_type": error_details["error_type"],
                "error_message": error_details["error_message"],
                "traceback": error_details["traceback"],
                "path": str(request.url.path),
                "method": request.method
            }
        )
    else:
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal Server Error",
                "error_type": error_details["error_type"],
                "error_message": error_details["error_message"],
                "traceback": error_details["traceback"]  # Include traceback even in production for debugging
            }
        )

@app.post("/chat")
def chat_endpoint(request:RequestState):
    logger.info(f"Received request for model: {request.model_name}, allow_search: {request.allow_search}")
    logger.info(f"Request details: messages_count={len(request.messages)}, system_prompt_length={len(request.system_prompt)}")

    if request.model_name not in settings.ALLOWED_MODEL_NAMES:
        logger.warning(f"Invalid model name: {request.model_name}. Allowed: {settings.ALLOWED_MODEL_NAMES}")
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid model name: {request.model_name}. Allowed models: {', '.join(settings.ALLOWED_MODEL_NAMES)}"
        )
    
    try:
        logger.info(f"Calling get_response_from_ai_agents for model: {request.model_name}")
        response = get_response_from_ai_agents(
            request.model_name,
            request.messages,
            request.allow_search,
            request.system_prompt
        )

        logger.info(f"Successfully got response from AI Agent {request.model_name}")
        return {"response": response}
    
    except ValueError as e:
        error_msg = str(e)
        error_details = log_full_traceback(logger, e, f"ValueError in /chat endpoint: ")
        
        # Check for specific ValueError cases
        if "TAVILY_API_KEY" in error_msg:
            logger.error(f"TAVILY_API_KEY is missing but allow_search=True")
            raise HTTPException(
                status_code=400,
                detail={
                    "error": "TAVILY_API_KEY is required when allow_search is True",
                    "error_type": "ValueError",
                    "error_message": error_msg,
                    "traceback": error_details["traceback"] if DEBUG_MODE else None
                }
            )
        
        raise HTTPException(
            status_code=400,
            detail={
                "error": "Validation Error",
                "error_type": "ValueError",
                "error_message": error_msg,
                "traceback": error_details["traceback"] if DEBUG_MODE else None
            }
        )
    
    except BadRequestError as e:
        if BadRequestError:
            error_msg = str(e)
            error_details = log_full_traceback(logger, e, f"Groq BadRequestError in /chat endpoint: ")
            
            if "decommissioned" in error_msg.lower() or "model_decommissioned" in error_msg:
                logger.error(f"Model {request.model_name} has been decommissioned: {error_msg}")
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error": "Model Decommissioned",
                        "error_message": f"Model '{request.model_name}' has been decommissioned",
                        "supported_models": settings.ALLOWED_MODEL_NAMES,
                        "traceback": error_details["traceback"] if DEBUG_MODE else None
                    }
                )
            
            logger.error(f"Groq API BadRequestError: {error_msg}")
            raise HTTPException(
                status_code=400,
                detail={
                    "error": "Groq API Error",
                    "error_type": "BadRequestError",
                    "error_message": error_msg,
                    "traceback": error_details["traceback"] if DEBUG_MODE else None
                }
            )
    
    except Exception as e:
        error_msg = str(e)
        error_details = log_full_traceback(logger, e, f"Unexpected error in /chat endpoint: ")
        
        # Check for decommissioned model in error message
        if "decommissioned" in error_msg.lower() or "model_decommissioned" in error_msg:
            logger.error(f"Model {request.model_name} has been decommissioned: {error_msg}")
            raise HTTPException(
                status_code=400,
                detail={
                    "error": "Model Decommissioned",
                    "error_message": f"Model '{request.model_name}' has been decommissioned",
                    "supported_models": settings.ALLOWED_MODEL_NAMES,
                    "traceback": error_details["traceback"] if DEBUG_MODE else None
                }
            )
        
        # For all other errors, return full traceback
        logger.error(f"Unexpected error during response generation: {error_msg}")
        raise HTTPException(
            status_code=500,
            detail={
                "error": "Internal Server Error",
                "error_type": error_details["error_type"],
                "error_message": error_details["error_message"],
                "traceback": error_details["traceback"],  # Always include traceback for debugging
                "request_details": {
                    "model_name": request.model_name,
                    "allow_search": request.allow_search,
                    "messages_count": len(request.messages)
                }
            }
        )
    



