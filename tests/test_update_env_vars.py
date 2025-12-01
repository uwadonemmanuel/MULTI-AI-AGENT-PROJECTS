"""Tests for update-env-vars.py module"""
import pytest
import json
import os
import tempfile
from unittest.mock import patch, mock_open
import sys

# Add parent directory to path to import update-env-vars
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from update_env_vars import update_task_definition


class TestUpdateEnvVars:
    """Test cases for update-env-vars module"""
    
    @pytest.fixture
    def sample_task_def(self):
        """Create a sample task definition"""
        return {
            "family": "test-family",
            "containerDefinitions": [
                {
                    "name": "test-container",
                    "image": "test-image",
                    "environment": [
                        {"name": "EXISTING_VAR", "value": "existing_value"}
                    ]
                }
            ],
            "cpu": "256",
            "memory": "512",
            "networkMode": "awsvpc",
            "requiresCompatibilities": ["FARGATE"],
            "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
        }
    
    def test_update_task_definition_with_groq_key(self, sample_task_def):
        """Test updating task definition with GROQ_API_KEY"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
            json.dump(sample_task_def, f)
            temp_file = f.name
        
        try:
            result_file = update_task_definition(
                temp_file,
                groq_key="test_groq_key",
                tavily_key=None
            )
            
            with open(result_file, 'r') as f:
                updated_def = json.load(f)
            
            env_vars = updated_def["containerDefinitions"][0]["environment"]
            groq_var = next((v for v in env_vars if v["name"] == "GROQ_API_KEY"), None)
            
            assert groq_var is not None
            assert groq_var["value"] == "test_groq_key"
            assert os.path.exists(result_file)
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
            if os.path.exists(result_file):
                os.unlink(result_file)
    
    def test_update_task_definition_with_tavily_key(self, sample_task_def):
        """Test updating task definition with TAVILY_API_KEY"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
            json.dump(sample_task_def, f)
            temp_file = f.name
        
        try:
            result_file = update_task_definition(
                temp_file,
                groq_key=None,
                tavily_key="test_tavily_key"
            )
            
            with open(result_file, 'r') as f:
                updated_def = json.load(f)
            
            env_vars = updated_def["containerDefinitions"][0]["environment"]
            tavily_var = next((v for v in env_vars if v["name"] == "TAVILY_API_KEY"), None)
            
            assert tavily_var is not None
            assert tavily_var["value"] == "test_tavily_key"
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
            if os.path.exists(result_file):
                os.unlink(result_file)
    
    def test_update_task_definition_with_both_keys(self, sample_task_def):
        """Test updating task definition with both keys"""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
            json.dump(sample_task_def, f)
            temp_file = f.name
        
        try:
            result_file = update_task_definition(
                temp_file,
                groq_key="test_groq_key",
                tavily_key="test_tavily_key"
            )
            
            with open(result_file, 'r') as f:
                updated_def = json.load(f)
            
            env_vars = updated_def["containerDefinitions"][0]["environment"]
            groq_var = next((v for v in env_vars if v["name"] == "GROQ_API_KEY"), None)
            tavily_var = next((v for v in env_vars if v["name"] == "TAVILY_API_KEY"), None)
            
            assert groq_var is not None
            assert tavily_var is not None
            assert groq_var["value"] == "test_groq_key"
            assert tavily_var["value"] == "test_tavily_key"
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
            if os.path.exists(result_file):
                os.unlink(result_file)
    
    def test_update_task_definition_replaces_existing_keys(self, sample_task_def):
        """Test that existing API keys are replaced"""
        # Add existing keys to task definition
        sample_task_def["containerDefinitions"][0]["environment"].extend([
            {"name": "GROQ_API_KEY", "value": "old_groq_key"},
            {"name": "TAVILY_API_KEY", "value": "old_tavily_key"}
        ])
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
            json.dump(sample_task_def, f)
            temp_file = f.name
        
        try:
            result_file = update_task_definition(
                temp_file,
                groq_key="new_groq_key",
                tavily_key="new_tavily_key"
            )
            
            with open(result_file, 'r') as f:
                updated_def = json.load(f)
            
            env_vars = updated_def["containerDefinitions"][0]["environment"]
            groq_var = next((v for v in env_vars if v["name"] == "GROQ_API_KEY"), None)
            tavily_var = next((v for v in env_vars if v["name"] == "TAVILY_API_KEY"), None)
            
            assert groq_var["value"] == "new_groq_key"
            assert tavily_var["value"] == "new_tavily_key"
            
            # Verify old values are not present
            old_groq = [v for v in env_vars if v["name"] == "GROQ_API_KEY" and v["value"] == "old_groq_key"]
            assert len(old_groq) == 0
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
            if os.path.exists(result_file):
                os.unlink(result_file)


