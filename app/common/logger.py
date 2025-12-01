import logging
import os
import sys
from datetime import datetime
import traceback

LOGS_DIR = "logs"
os.makedirs(LOGS_DIR,exist_ok=True)

LOG_FILE = os.path.join(LOGS_DIR, f"log_{datetime.now().strftime('%Y-%m-%d')}.log")

# Configure logging to both file and console (for CloudWatch)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)  # This ensures logs go to CloudWatch
    ]
)

def get_logger(name):
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    return logger

def log_full_traceback(logger, error, context=""):
    """Log full traceback with context"""
    error_type = type(error).__name__
    error_msg = str(error)
    full_traceback = traceback.format_exc()
    
    logger.error(f"{context}Error Type: {error_type}")
    logger.error(f"{context}Error Message: {error_msg}")
    logger.error(f"{context}Full Traceback:\n{full_traceback}")
    
    return {
        "error_type": error_type,
        "error_message": error_msg,
        "traceback": full_traceback
    }