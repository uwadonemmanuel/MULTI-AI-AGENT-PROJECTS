"""Tests for app.common.logger module"""
import pytest
import logging
import os
from unittest.mock import patch, MagicMock
from app.common.logger import get_logger, log_full_traceback


class TestLogger:
    """Test cases for logger module"""
    
    def test_get_logger(self):
        """Test get_logger function returns a logger"""
        logger = get_logger("test_module")
        assert isinstance(logger, logging.Logger)
        assert logger.name == "test_module"
    
    def test_get_logger_different_modules(self):
        """Test that different modules get different loggers"""
        logger1 = get_logger("module1")
        logger2 = get_logger("module2")
        
        assert logger1.name == "module1"
        assert logger2.name == "module2"
        assert logger1 is not logger2
    
    def test_log_full_traceback(self):
        """Test log_full_traceback function"""
        logger = get_logger("test_module")
        
        try:
            raise ValueError("Test error")
        except ValueError as e:
            result = log_full_traceback(logger, e, "Test context: ")
            
            assert isinstance(result, dict)
            assert result["error_type"] == "ValueError"
            assert result["error_message"] == "Test error"
            assert "traceback" in result
            assert len(result["traceback"]) > 0
    
    def test_log_full_traceback_with_context(self):
        """Test log_full_traceback with context"""
        logger = get_logger("test_module")
        
        try:
            raise RuntimeError("Runtime error")
        except RuntimeError as e:
            result = log_full_traceback(logger, e, "Custom context: ")
            
            assert result["error_type"] == "RuntimeError"
            assert result["error_message"] == "Runtime error"
    
    def test_log_full_traceback_empty_context(self):
        """Test log_full_traceback with empty context"""
        logger = get_logger("test_module")
        
        try:
            raise KeyError("Key not found")
        except KeyError as e:
            result = log_full_traceback(logger, e, "")
            
            assert result["error_type"] == "KeyError"
            assert result["error_message"] == "Key not found"


