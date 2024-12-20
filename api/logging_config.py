import logging
import logging.handlers
import os
import sys
from datetime import datetime

def setup_logging(log_dir: str = None):
    """
    Set up logging configuration for the API
    """
    if log_dir is None:
        log_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'logs')
    
    # Create logs directory if it doesn't exist
    os.makedirs(log_dir, exist_ok=True)
    
    # Create formatters
    console_formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s'
    )
    file_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
    )
    
    # Create handlers
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(console_formatter)
    console_handler.setLevel(logging.INFO)
    
    # Create rotating file handler for general logs
    api_log_file = os.path.join(log_dir, 'api.log')
    file_handler = logging.handlers.RotatingFileHandler(
        api_log_file,
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setFormatter(file_formatter)
    file_handler.setLevel(logging.DEBUG)
    
    # Create session-specific log handler
    session_log_file = os.path.join(log_dir, 'sessions.log')
    session_handler = logging.handlers.RotatingFileHandler(
        session_log_file,
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    session_handler.setFormatter(file_formatter)
    session_handler.setLevel(logging.DEBUG)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    root_logger.addHandler(console_handler)
    root_logger.addHandler(file_handler)
    
    # Configure session logger
    session_logger = logging.getLogger('session')
    session_logger.setLevel(logging.DEBUG)
    session_logger.addHandler(session_handler)
    
    # Configure API logger
    api_logger = logging.getLogger('api')
    api_logger.setLevel(logging.DEBUG)
    
    return api_logger, session_logger

def log_session_event(logger, account: str, event_type: str, details: dict = None):
    """
    Log a session-related event with standardized formatting
    """
    if details is None:
        details = {}
    
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'account': account,
        'event': event_type,
        **details
    }
    
    logger.info(f"Session Event: {log_entry}")
    return log_entry
