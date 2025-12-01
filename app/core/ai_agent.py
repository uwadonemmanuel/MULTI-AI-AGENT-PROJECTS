from langchain_groq import ChatGroq
from langchain_tavily import TavilySearch

from langgraph.prebuilt import create_react_agent
from langchain_core.messages.ai import AIMessage
from langchain_core.messages.human import HumanMessage

from app.config.settings import settings
from app.common.logger import get_logger, log_full_traceback

logger = get_logger(__name__)

def get_response_from_ai_agents(llm_id, query, allow_search, system_prompt):
    """
    Get response from AI agents with full error logging
    
    Args:
        llm_id: Model identifier
        query: List of message strings
        allow_search: Whether to enable web search
        system_prompt: System prompt for the agent
        
    Returns:
        str: AI response message
        
    Raises:
        ValueError: If required API keys are missing
        Exception: Any other error with full traceback logged
    """
    try:
        logger.info(f"Initializing ChatGroq with model: {llm_id}")
        
        # Check if GROQ_API_KEY is set
        if not settings.GROQ_API_KEY:
            error_msg = "GROQ_API_KEY is not set in environment variables"
            logger.error(error_msg)
            raise ValueError(error_msg)
        
        llm = ChatGroq(model=llm_id)
        logger.info("ChatGroq initialized successfully")

        if allow_search:
            logger.info("Search is enabled, checking TAVILY_API_KEY")
            if not settings.TAVILY_API_KEY:
                error_msg = "TAVILY_API_KEY is required when allow_search is True"
                logger.error(error_msg)
                raise ValueError(error_msg)
            tools = [TavilySearch(max_results=2, tavily_api_key=settings.TAVILY_API_KEY)]
            logger.info("TavilySearch tool configured")
        else:
            tools = []
            logger.info("Search is disabled, no tools configured")

        logger.info(f"Creating react agent with {len(tools)} tool(s)")
        agent = create_react_agent(
            model=llm,
            tools=tools,
            prompt=system_prompt
        )
        logger.info("React agent created successfully")

        # Convert string messages to HumanMessage objects
        logger.info(f"Converting {len(query)} message(s) to HumanMessage objects")
        messages = [HumanMessage(content=msg) for msg in query]
        state = {"messages": messages}

        logger.info("Invoking agent...")
        response = agent.invoke(state)
        logger.info("Agent invocation completed")

        messages = response.get("messages", [])
        logger.info(f"Retrieved {len(messages)} message(s) from response")

        ai_messages = [message.content for message in messages if isinstance(message, AIMessage)]
        
        if not ai_messages:
            error_msg = "No AI messages found in response"
            logger.error(error_msg)
            logger.error(f"Response messages: {[type(m).__name__ for m in messages]}")
            raise ValueError(error_msg)
        
        logger.info(f"Extracted AI response (length: {len(ai_messages[-1])})")
        return ai_messages[-1]
        
    except ValueError as e:
        # Re-raise ValueError as-is (already logged)
        raise
    except Exception as e:
        # Log full traceback for any other exception
        log_full_traceback(logger, e, "Error in get_response_from_ai_agents: ")
        # Re-raise to be handled by API layer
        raise






