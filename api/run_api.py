import os
import sys

# Add the current directory to Python path so relative imports work
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

# Import the FastAPI app using relative import
from main import app
