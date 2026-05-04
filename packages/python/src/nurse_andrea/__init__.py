from .configuration import configure, get_config, is_enabled
from .client import get_client
from .deploy import deploy

def django_middleware():
    from .middleware.django import NurseAndreaDjangoMiddleware
    return NurseAndreaDjangoMiddleware

def fastapi_middleware():
    from .middleware.fastapi import NurseAndreaFastAPIMiddleware
    return NurseAndreaFastAPIMiddleware

def flask_init_app(app):
    from .middleware.flask import init_app
    return init_app(app)

def intercept_logging(level=None):
    from .interceptors.stdlib_logging import intercept_root_logger
    import logging
    return intercept_root_logger(level or logging.WARNING)

def structlog_processor():
    from .interceptors.structlog import NurseAndreaStructlogProcessor
    return NurseAndreaStructlogProcessor()

def loguru_sink():
    from .interceptors.loguru import nurse_andrea_loguru_sink
    return nurse_andrea_loguru_sink

__version__ = "0.2.1"
__all__ = [
    "configure", "get_config", "is_enabled", "get_client",
    "django_middleware", "fastapi_middleware", "flask_init_app",
    "intercept_logging", "structlog_processor", "loguru_sink",
    "deploy",
    "__version__",
]
