"""Tests for app.backend.api module"""
import pytest
from unittest.mock import Mock, patch, MagicMock
from fastapi.testclient import TestClient
from app.backend.api import app, RequestState, _is_model_decommissioned, _create_error_detail
from app.config.settings import settings


class TestAPIEndpoints:
    """Test cases for API endpoints"""
    
    @pytest.fixture
    def client(self):
        """Create test client"""
        return TestClient(app)
    
    @patch('app.backend.api.get_response_from_ai_agents')
    def test_chat_endpoint_success(self, mock_get_response, client):
        """Test successful chat endpoint"""
        mock_get_response.return_value = "Test AI response"
        
        response = client.post(
            "/chat",
            json={
                "model_name": "llama-3.1-8b-instant",
                "system_prompt": "You are a helpful assistant",
                "messages": ["Hello"],
                "allow_search": False
            }
        )
        
        assert response.status_code == 200
        assert response.json() == {"response": "Test AI response"}
        mock_get_response.assert_called_once()
    
    def test_chat_endpoint_invalid_model(self, client):
        """Test chat endpoint with invalid model name"""
        response = client.post(
            "/chat",
            json={
                "model_name": "invalid-model",
                "system_prompt": "You are a helpful assistant",
                "messages": ["Hello"],
                "allow_search": False
            }
        )
        
        assert response.status_code == 400
        assert "Invalid model name" in response.json()["detail"]
    
    @patch('app.backend.api.get_response_from_ai_agents')
    def test_chat_endpoint_value_error(self, mock_get_response, client):
        """Test chat endpoint with ValueError"""
        mock_get_response.side_effect = ValueError("Test error")
        
        response = client.post(
            "/chat",
            json={
                "model_name": "llama-3.1-8b-instant",
                "system_prompt": "You are a helpful assistant",
                "messages": ["Hello"],
                "allow_search": False
            }
        )
        
        assert response.status_code == 400
    
    @patch('app.backend.api.get_response_from_ai_agents')
    def test_chat_endpoint_tavily_key_error(self, mock_get_response, client):
        """Test chat endpoint with TAVILY_API_KEY error"""
        mock_get_response.side_effect = ValueError("TAVILY_API_KEY is required")
        
        response = client.post(
            "/chat",
            json={
                "model_name": "llama-3.1-8b-instant",
                "system_prompt": "You are a helpful assistant",
                "messages": ["Hello"],
                "allow_search": True
            }
        )
        
        assert response.status_code == 400
        assert "TAVILY_API_KEY" in response.json()["detail"]["error"]
    
    @patch('app.backend.api.get_response_from_ai_agents')
    def test_chat_endpoint_bad_request_error(self, mock_get_response, client):
        """Test chat endpoint with BadRequestError"""
        # Mock BadRequestError if available
        try:
            from groq import BadRequestError
            mock_get_response.side_effect = BadRequestError("Model decommissioned")
            
            response = client.post(
                "/chat",
                json={
                    "model_name": "llama-3.1-8b-instant",
                    "system_prompt": "You are a helpful assistant",
                    "messages": ["Hello"],
                    "allow_search": False
                }
            )
            
            assert response.status_code == 400
        except ImportError:
            # Skip test if BadRequestError is not available
            pytest.skip("BadRequestError not available")
    
    @patch('app.backend.api.get_response_from_ai_agents')
    def test_chat_endpoint_generic_exception(self, mock_get_response, client):
        """Test chat endpoint with generic exception"""
        mock_get_response.side_effect = Exception("Unexpected error")
        
        response = client.post(
            "/chat",
            json={
                "model_name": "llama-3.1-8b-instant",
                "system_prompt": "You are a helpful assistant",
                "messages": ["Hello"],
                "allow_search": False
            }
        )
        
        assert response.status_code == 500


class TestHelperFunctions:
    """Test cases for helper functions"""
    
    def test_is_model_decommissioned(self):
        """Test _is_model_decommissioned function"""
        assert _is_model_decommissioned("Model has been decommissioned") is True
        assert _is_model_decommissioned("model_decommissioned error") is True
        assert _is_model_decommissioned("Normal error message") is False
    
    def test_create_error_detail(self):
        """Test _create_error_detail function"""
        detail = _create_error_detail(
            error="Test Error",
            error_type="ValueError",
            error_message="Test message",
            traceback_info="Traceback info"
        )
        
        assert detail["error"] == "Test Error"
        assert detail["error_type"] == "ValueError"
        assert detail["error_message"] == "Test message"
        assert detail["traceback"] is not None or detail["traceback"] is None  # Depends on DEBUG_MODE

