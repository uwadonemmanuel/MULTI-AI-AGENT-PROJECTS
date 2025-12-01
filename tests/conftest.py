"""Pytest configuration and shared fixtures"""
import pytest
import os
from unittest.mock import patch


@pytest.fixture(autouse=True)
def reset_settings():
    """Reset settings before each test"""
    with patch('app.config.settings.settings') as mock_settings:
        yield mock_settings


@pytest.fixture
def mock_env_vars(monkeypatch):
    """Mock environment variables"""
    monkeypatch.setenv("GROQ_API_KEY", "test_groq_key")
    monkeypatch.setenv("TAVILY_API_KEY", "test_tavily_key")
    yield
    # Cleanup
    monkeypatch.delenv("GROQ_API_KEY", raising=False)
    monkeypatch.delenv("TAVILY_API_KEY", raising=False)


