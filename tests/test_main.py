"""Tests for app.main module"""
import pytest
from unittest.mock import patch, MagicMock, call
from app.main import run_backend, run_frontend


class TestMain:
    """Test cases for main module"""
    
    @patch('app.main.subprocess.run')
    @patch('app.main.logger')
    def test_run_backend(self, mock_logger, mock_subprocess):
        """Test run_backend function"""
        # Mock subprocess to raise CalledProcessError to stop execution
        from subprocess import CalledProcessError
        mock_subprocess.side_effect = CalledProcessError(1, "uvicorn")
        
        # Should raise CalledProcessError
        with pytest.raises(Exception):
            run_backend()
        
        # Verify subprocess was called with correct arguments
        mock_subprocess.assert_called_once()
        call_args = mock_subprocess.call_args[0][0]
        assert "uvicorn" in call_args
        assert "app.backend.api:app" in call_args
        assert "--host" in call_args
        assert "0.0.0.0" in call_args
        assert "--port" in call_args
        assert "9999" in call_args
    
    @patch('app.main.subprocess.run')
    @patch('app.main.logger')
    def test_run_frontend(self, mock_logger, mock_subprocess):
        """Test run_frontend function"""
        # Mock subprocess to raise CalledProcessError to stop execution
        from subprocess import CalledProcessError
        mock_subprocess.side_effect = CalledProcessError(1, "streamlit")
        
        # Should raise CalledProcessError
        with pytest.raises(Exception):
            run_frontend()
        
        # Verify subprocess was called with correct arguments
        mock_subprocess.assert_called_once()
        call_args = mock_subprocess.call_args[0][0]
        assert "streamlit" in call_args
        assert "app/frontend/ui.py" in call_args
        assert "--server.address" in call_args
        assert "0.0.0.0" in call_args
        assert "--server.port" in call_args
        assert "8501" in call_args

