#!/usr/bin/env python3
"""
Quick test to start the server and test the classification endpoint.
"""
import sys
import os
import time
import requests
import threading
import subprocess
from io import BytesIO

# Add current directory to path for imports
sys.path.insert(0, '.')
sys.path.insert(0, 'src')

def test_classification_api():
    """Test the classification API with a real image."""
    print("=== API Integration Test ===")
    
    # Test with a real clothing image
    test_image = "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg"
    
    if not os.path.exists(test_image):
        print("❌ Test image not found")
        return False
    
    try:
        # Test the server
        print("Testing API server...")
        
        # Test health endpoint
        try:
            response = requests.get("http://127.0.0.1:8000/health", timeout=5)
            if response.status_code == 200:
                print("✅ Health endpoint working")
            else:
                print(f"❌ Health endpoint failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Cannot connect to server: {e}")
            print("Make sure to run: python -c 'import sys; sys.path.insert(0, \".\"); from src.api.server import app; import uvicorn; uvicorn.run(app, host=\"127.0.0.1\", port=8000)' in another terminal")
            return False
        
        # Test classification endpoint
        print(f"Testing classification with: {os.path.basename(test_image)}")
        
        with open(test_image, 'rb') as f:
            files = {'image': (os.path.basename(test_image), f, 'image/jpeg')}
            response = requests.post("http://127.0.0.1:8000/classify-image", files=files, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ API Classification Results:")
            print(f"  Category: {result.get('category')}")
            print(f"  Category Confidence: {result.get('category_confidence', 0):.2f}")
            print(f"  Color: {result.get('color')}")
            print(f"  Color Confidence: {result.get('color_confidence', 0):.2f}")
            print("✅ Full integration working!")
            return True
        else:
            print(f"❌ Classification failed: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing API: {e}")
        return False

def start_server_simple():
    """Start the server using a simple approach."""
    print("Starting server with direct import...")
    
    try:
        # Import and run server directly
        from src.api.server import app
        import uvicorn
        
        print("✅ Server modules imported successfully")
        print("Starting server on http://127.0.0.1:8000")
        print("Press Ctrl+C to stop the server")
        
        uvicorn.run(app, host="127.0.0.1", port=8000)
        
    except Exception as e:
        print(f"❌ Error starting server: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--server":
        # Start server mode
        start_server_simple()
    else:
        # Test mode
        test_classification_api()