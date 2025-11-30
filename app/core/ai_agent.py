from langchain_groq import ChatGroq
from langchain_tavily import TavilySearch

from langgraph.prebuilt import create_react_agent
from langchain_core.messages.ai import AIMessage
from langchain_core.messages.human import HumanMessage

from app.config.settings import settings

def get_response_from_ai_agents(llm_id , query , allow_search ,system_prompt):

    llm = ChatGroq(model=llm_id)

    if allow_search:
        if not settings.TAVILY_API_KEY:
            raise ValueError("TAVILY_API_KEY is required when allow_search is True")
        tools = [TavilySearch(max_results=2, tavily_api_key=settings.TAVILY_API_KEY)]
    else:
        tools = []

    agent = create_react_agent(
        model=llm,
        tools=tools,
        prompt=system_prompt
    )

    # Convert string messages to HumanMessage objects
    messages = [HumanMessage(content=msg) for msg in query]
    state = {"messages": messages}

    response = agent.invoke(state)

    messages = response.get("messages")

    ai_messages = [message.content for message in messages if isinstance(message,AIMessage)]

    return ai_messages[-1]






