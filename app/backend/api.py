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

# Error messages
INTERNAL_SERVER_ERROR = "Internal Server Error"

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

# Helper functions for error handling
def _is_model_decommissioned(error_msg: str) -> bool:
    """Check if error message indicates model is decommissioned"""
    return "decommissioned" in error_msg.lower() or "model_decommissioned" in error_msg

def _create_error_detail(error: str, error_type: str, error_message: str, 
                        traceback_info: str = None, **kwargs) -> dict:
    """Create standardized error detail dictionary"""
    detail = {
        "error": error,
        "error_type": error_type,
        "error_message": error_message,
        "traceback": traceback_info if DEBUG_MODE else None
    }
    detail.update(kwargs)
    return detail

def _handle_value_error(e: ValueError, request: RequestState) -> HTTPException:
    """Handle ValueError exceptions"""
    error_msg = str(e)
    error_details = log_full_traceback(logger, e, "ValueError in /chat endpoint: ")
    
    if "TAVILY_API_KEY" in error_msg:
        logger.error("TAVILY_API_KEY is missing but allow_search=True")
        return HTTPException(
            status_code=400,
            detail=_create_error_detail(
                "TAVILY_API_KEY is required when allow_search is True",
                "ValueError",
                error_msg,
                error_details["traceback"]
            )
        )
    
    return HTTPException(
        status_code=400,
        detail=_create_error_detail(
            "Validation Error",
            "ValueError",
            error_msg,
            error_details["traceback"]
        )
    )

def _handle_bad_request_error(e: Exception, request: RequestState) -> HTTPException:
    """Handle BadRequestError exceptions from Groq"""
    error_msg = str(e)
    error_details = log_full_traceback(logger, e, "Groq BadRequestError in /chat endpoint: ")
    
    if _is_model_decommissioned(error_msg):
        logger.error(f"Model {request.model_name} has been decommissioned: {error_msg}")
        return HTTPException(
            status_code=400,
            detail=_create_error_detail(
                "Model Decommissioned",
                "BadRequestError",
                f"Model '{request.model_name}' has been decommissioned",
                error_details["traceback"],
                supported_models=settings.ALLOWED_MODEL_NAMES
            )
        )
    
    logger.error(f"Groq API BadRequestError: {error_msg}")
    return HTTPException(
        status_code=400,
        detail=_create_error_detail(
            "Groq API Error",
            "BadRequestError",
            error_msg,
            error_details["traceback"]
        )
    )

def _handle_generic_exception(e: Exception, request: RequestState) -> HTTPException:
    """Handle generic exceptions"""
    error_msg = str(e)
    error_details = log_full_traceback(logger, e, "Unexpected error in /chat endpoint: ")
    
    if _is_model_decommissioned(error_msg):
        logger.error(f"Model {request.model_name} has been decommissioned: {error_msg}")
        return HTTPException(
            status_code=400,
            detail=_create_error_detail(
                "Model Decommissioned",
                type(e).__name__,
                f"Model '{request.model_name}' has been decommissioned",
                error_details["traceback"],
                supported_models=settings.ALLOWED_MODEL_NAMES
            )
        )
    
    logger.error(f"Unexpected error during response generation: {error_msg}")
    return HTTPException(
        status_code=500,
        detail=_create_error_detail(
            INTERNAL_SERVER_ERROR,
            error_details["error_type"],
            error_details["error_message"],
            error_details["traceback"],
            request_details={
                "model_name": request.model_name,
                "allow_search": request.allow_search,
                "messages_count": len(request.messages)
            }
        )
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler to catch all unhandled exceptions"""
    error_details = log_full_traceback(logger, exc, f"Unhandled exception in {request.url.path}: ")
    
    if DEBUG_MODE:
        return JSONResponse(
            status_code=500,
            content={
                "error": INTERNAL_SERVER_ERROR,
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
                "error": INTERNAL_SERVER_ERROR,
                "error_type": error_details["error_type"],
                "error_message": error_details["error_message"],
                "traceback": error_details["traceback"]  # Include traceback even in production for debugging
            }
        )

@app.post("/chat")
def chat_endpoint(request: RequestState):
    """Handle chat requests to AI agents"""
    logger.info(f"Received request for model: {request.model_name}, allow_search: {request.allow_search}")
    logger.info(f"Request details: messages_count={len(request.messages)}, system_prompt_length={len(request.system_prompt)}")

    # Validate model name
    if request.model_name not in settings.ALLOWED_MODEL_NAMES:
        logger.warning(f"Invalid model name: {request.model_name}. Allowed: {settings.ALLOWED_MODEL_NAMES}")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid model name: {request.model_name}. Allowed models: {', '.join(settings.ALLOWED_MODEL_NAMES)}"
        )
    
    # Process request
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
        raise _handle_value_error(e, request)
    
    except BadRequestError as e:
        if BadRequestError:  # Check if BadRequestError is available (not None)
            raise _handle_bad_request_error(e, request)
        # If BadRequestError is None, re-raise as generic exception
        raise _handle_generic_exception(e, request)
    
    except Exception as e:
        raise _handle_generic_exception(e, request)
    



