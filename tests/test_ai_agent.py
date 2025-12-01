"""Tests for app.core.ai_agent module"""
import pytest
from unittest.mock import Mock, patch, MagicMock
from app.core.ai_agent import get_response_from_ai_agents
from langchain_core.messages.ai import AIMessage


class TestGetResponseFromAIAgents:
    """Test cases for get_response_from_ai_agents function"""
    
    @patch('app.core.ai_agent.settings')
    def test_missing_groq_api_key(self, mock_settings):
        """Test that missing GROQ_API_KEY raises ValueError"""
        mock_settings.GROQ_API_KEY = None
        mock_settings.TAVILY_API_KEY = "test_key"
        
        with pytest.raises(ValueError, match="GROQ_API_KEY is not set"):
            get_response_from_ai_agents(
                llm_id="llama-3.1-8b-instant",
                query=["test message"],
                allow_search=False,
                system_prompt="You are a helpful assistant"
            )
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    def test_missing_tavily_api_key_with_search(self, mock_chatgroq, mock_settings):
        """Test that missing TAVILY_API_KEY raises ValueError when allow_search=True"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = None
        
        with pytest.raises(ValueError, match="TAVILY_API_KEY is required"):
            get_response_from_ai_agents(
                llm_id="llama-3.1-8b-instant",
                query=["test message"],
                allow_search=True,
                system_prompt="You are a helpful assistant"
            )
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    @patch('app.core.ai_agent.create_react_agent')
    def test_successful_response_without_search(self, mock_create_agent, mock_chatgroq, mock_settings):
        """Test successful response generation without search"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = "test_tavily_key"
        
        # Mock the agent and response with proper AIMessage
        mock_agent = MagicMock()
        mock_ai_message = AIMessage(content="Test response")
        
        mock_response = {
            "messages": [mock_ai_message]
        }
        mock_agent.invoke.return_value = mock_response
        mock_create_agent.return_value = mock_agent
        
        result = get_response_from_ai_agents(
            llm_id="llama-3.1-8b-instant",
            query=["test message"],
            allow_search=False,
            system_prompt="You are a helpful assistant"
        )
        
        assert result == "Test response"
        mock_agent.invoke.assert_called_once()
        mock_chatgroq.assert_called_once_with(model="llama-3.1-8b-instant")
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    @patch('app.core.ai_agent.TavilySearch')
    @patch('app.core.ai_agent.create_react_agent')
    def test_successful_response_with_search(self, mock_create_agent, mock_tavily, mock_chatgroq, mock_settings):
        """Test successful response generation with search enabled"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = "test_tavily_key"
        
        # Mock the agent and response with proper AIMessage
        mock_agent = MagicMock()
        mock_ai_message = AIMessage(content="Test response with search")
        
        mock_response = {
            "messages": [mock_ai_message]
        }
        mock_agent.invoke.return_value = mock_response
        mock_create_agent.return_value = mock_agent
        
        result = get_response_from_ai_agents(
            llm_id="llama-3.1-8b-instant",
            query=["test message"],
            allow_search=True,
            system_prompt="You are a helpful assistant"
        )
        
        assert result == "Test response with search"
        mock_tavily.assert_called_once_with(max_results=2, tavily_api_key="test_tavily_key")
        mock_agent.invoke.assert_called_once()
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    @patch('app.core.ai_agent.create_react_agent')
    def test_no_ai_messages_in_response(self, mock_create_agent, mock_chatgroq, mock_settings):
        """Test that empty AI messages raises ValueError"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = "test_tavily_key"
        
        # Mock the agent with empty messages
        mock_agent = MagicMock()
        mock_response = {"messages": []}
        mock_agent.invoke.return_value = mock_response
        mock_create_agent.return_value = mock_agent
        
        with pytest.raises(ValueError, match="No AI messages found"):
            get_response_from_ai_agents(
                llm_id="llama-3.1-8b-instant",
                query=["test message"],
                allow_search=False,
                system_prompt="You are a helpful assistant"
            )
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    @patch('app.core.ai_agent.create_react_agent')
    def test_no_ai_messages_with_other_message_types(self, mock_create_agent, mock_chatgroq, mock_settings):
        """Test that non-AI messages don't count as AI messages"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = "test_tavily_key"
        
        # Mock the agent with non-AI messages
        from langchain_core.messages.human import HumanMessage
        mock_agent = MagicMock()
        mock_response = {"messages": [HumanMessage(content="Human message")]}
        mock_agent.invoke.return_value = mock_response
        mock_create_agent.return_value = mock_agent
        
        with pytest.raises(ValueError, match="No AI messages found"):
            get_response_from_ai_agents(
                llm_id="llama-3.1-8b-instant",
                query=["test message"],
                allow_search=False,
                system_prompt="You are a helpful assistant"
            )
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    @patch('app.core.ai_agent.create_react_agent')
    @patch('app.core.ai_agent.log_full_traceback')
    def test_generic_exception_handling(self, mock_log_traceback, mock_create_agent, mock_chatgroq, mock_settings):
        """Test that generic exceptions are logged and re-raised"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = "test_tavily_key"
        mock_log_traceback.return_value = {
            "error_type": "Exception",
            "error_message": "Test exception",
            "traceback": "Traceback..."
        }
        
        # Mock the agent to raise an exception
        mock_agent = MagicMock()
        mock_agent.invoke.side_effect = Exception("Test exception")
        mock_create_agent.return_value = mock_agent
        
        with pytest.raises(Exception, match="Test exception"):
            get_response_from_ai_agents(
                llm_id="llama-3.1-8b-instant",
                query=["test message"],
                allow_search=False,
                system_prompt="You are a helpful assistant"
            )
        
        mock_log_traceback.assert_called_once()
    
    @patch('app.core.ai_agent.settings')
    @patch('app.core.ai_agent.ChatGroq')
    @patch('app.core.ai_agent.create_react_agent')
    def test_multiple_ai_messages_returns_last(self, mock_create_agent, mock_chatgroq, mock_settings):
        """Test that when multiple AI messages exist, the last one is returned"""
        mock_settings.GROQ_API_KEY = "test_groq_key"
        mock_settings.TAVILY_API_KEY = "test_tavily_key"
        
        # Mock the agent with multiple AI messages
        mock_agent = MagicMock()
        mock_ai_message1 = AIMessage(content="First response")
        mock_ai_message2 = AIMessage(content="Second response")
        
        mock_response = {
            "messages": [mock_ai_message1, mock_ai_message2]
        }
        mock_agent.invoke.return_value = mock_response
        mock_create_agent.return_value = mock_agent
        
        result = get_response_from_ai_agents(
            llm_id="llama-3.1-8b-instant",
            query=["test message"],
            allow_search=False,
            system_prompt="You are a helpful assistant"
        )
        
        assert result == "Second response"

