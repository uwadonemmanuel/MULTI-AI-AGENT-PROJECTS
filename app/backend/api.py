from fastapi import FastAPI,HTTPException
from pydantic import BaseModel
from typing import List
from app.core.ai_agent import get_response_from_ai_agents
from app.config.settings import settings
from app.common.logger import get_logger
from app.common.custom_exception import CustomException

try:
    from groq import BadRequestError
except ImportError:
    BadRequestError = None

logger = get_logger(__name__)

app = FastAPI(title="MULTI AI AGENT")

class RequestState(BaseModel):
    model_name:str
    system_prompt:str
    messages:List[str]
    allow_search: bool

@app.post("/chat")
def chat_endpoint(request:RequestState):
    logger.info(f"Received request for model : {request.model_name}")

    if request.model_name not in settings.ALLOWED_MODEL_NAMES:
        logger.warning("Invalid model name")
        raise HTTPException(status_code=400 , detail="Invalid model name")
    
    try:
        response = get_response_from_ai_agents(
            request.model_name,
            request.messages,
            request.allow_search,
            request.system_prompt
        )

        logger.info(f"Sucesfully got response from AI Agent {request.model_name}")

        return {"response" : response}
    
    except Exception as e:
        error_msg = str(e)
        # Check for decommissioned model error (works even if BadRequestError import failed)
        if BadRequestError and isinstance(e, BadRequestError):
            if "decommissioned" in error_msg.lower() or "model_decommissioned" in error_msg:
                logger.error(f"Model {request.model_name} has been decommissioned: {error_msg}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Model '{request.model_name}' has been decommissioned. Please use one of the supported models: {', '.join(settings.ALLOWED_MODEL_NAMES)}"
                )
            logger.error(f"Groq API error: {error_msg}", exc_info=True)
            raise HTTPException(
                status_code=400,
                detail=f"Groq API error: {error_msg}"
            )
        # Check for decommissioned model in error message even if exception type check fails
        elif "decommissioned" in error_msg.lower() or "model_decommissioned" in error_msg:
            logger.error(f"Model {request.model_name} has been decommissioned: {error_msg}")
            raise HTTPException(
                status_code=400,
                detail=f"Model '{request.model_name}' has been decommissioned. Please use one of the supported models: {', '.join(settings.ALLOWED_MODEL_NAMES)}"
            )
        logger.error(f"Some error occurred during response generation: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500 , 
            detail=str(CustomException("Failed to get AI response" , error_detail=e))
            )
    



