"""
Logging configuration for the IDoc simulator
"""

import logging
import sys
from pythonjsonlogger import jsonlogger


def setup_logger(name: str = "idoc_simulator", level: str = "INFO") -> logging.Logger:
    """
    Configure and return a logger instance with JSON formatting
    
    Args:
        name: Logger name
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))
    
    # Remove existing handlers
    logger.handlers = []
    
    # Console handler with JSON formatting
    console_handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        '%(asctime)s %(name)s %(levelname)s %(message)s',
        timestamp=True
    )
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    return logger
