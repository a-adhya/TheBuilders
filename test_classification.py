#!/usr/bin/env python3
"""
Test script for clothing classification service.
This script tests the YOLO-based clothing classification functionality.

Usage:
    python test_classification.py [path_to_test_image]
    
If no image path is provided, it will create a simple test image.
"""

import os
import sys
import io

# Add src to path so we can import our services
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

# Try to import optional dependencies
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False
    print("Warning: requests not available - API tests will be skipped")

try:
    from PIL import Image, ImageDraw
    import numpy as np
    HAS_IMAGING = True
except ImportError:
    HAS_IMAGING = False
    print("Warning: PIL/numpy not available - will use basic tests only")

def create_test_image():
    """Load a real clothing image for classification."""
    # Try to use real clothing images from test_imgs folder
    test_image_paths = [
        "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
        "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg",
        "YoloV8/test_imgs/646f1540b7426a82fcb0629f7c55ae062eaf0742.jpg"
    ]
    
    # Try to load the first available real image
    for img_path in test_image_paths:
        if os.path.exists(img_path):
            print(f"Using real clothing image: {img_path}")
            with open(img_path, 'rb') as f:
                return f.read()
    
    # Fallback to synthetic image if no real images found
    if not HAS_IMAGING:
        return None
    
    print("No real images found, using synthetic test image")
    # Create a simple colored rectangle image
    img = Image.new('RGB', (640, 480), color='red')
    draw = ImageDraw.Draw(img)
    
    # Draw a simple shirt-like shape
    draw.rectangle([200, 100, 440, 300], fill='blue', outline='black', width=3)
    draw.rectangle([180, 120, 460, 180], fill='blue', outline='black', width=2)  # shoulders
    
    # Save to bytes
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    return img_bytes.getvalue()

def test_classification_service():
    """Test the classification service directly with real clothing images."""
    print("Testing ClassificationService directly...")
    
    try:
        from src.services.classification_service import ClothingClassificationService
        
        # Initialize service
        service = ClothingClassificationService()
        
        # Test with all available real clothing images
        test_image_paths = [
            "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
            "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg",
            "YoloV8/test_imgs/646f1540b7426a82fcb0629f7c55ae062eaf0742.jpg"
        ]
        
        success_count = 0
        total_tests = 0
        
        for img_path in test_image_paths:
            if os.path.exists(img_path):
                total_tests += 1
                print(f"\n--- Testing image: {os.path.basename(img_path)} ---")
                
                with open(img_path, 'rb') as f:
                    image_data = f.read()
                
                # Test classification
                result = service.classify_image(image_data)
                
                print(f"  Category: {result.get('category')}")
                print(f"  Category confidence: {result.get('category_confidence', 0):.2f}")
                print(f"  Color: {result.get('color')}")
                print(f"  Color confidence: {result.get('color_confidence', 0):.2f}")
                print(f"  Success: {result.get('success')}")
                if result.get('error'):
                    print(f"  Error: {result.get('error')}")
                
                if result.get('success', False):
                    success_count += 1
        
        # Fallback to synthetic image if no real images found
        if total_tests == 0:
            print("No real clothing images found, testing with synthetic image...")
            image_data = create_test_image()
            if image_data:
                total_tests = 1
                result = service.classify_image(image_data)
                
                print("Synthetic image test results:")
                print(f"  Category: {result.get('category')}")
                print(f"  Category confidence: {result.get('category_confidence', 0):.2f}")
                print(f"  Color: {result.get('color')}")
                print(f"  Color confidence: {result.get('color_confidence', 0):.2f}")
                print(f"  Success: {result.get('success')}")
                
                if result.get('success', False):
                    success_count = 1
        
        print(f"\nClassification test summary: {success_count}/{total_tests} images processed successfully")
        return success_count > 0
        
    except Exception as e:
        print(f"Error testing service directly: {e}")
        return False

def test_api_endpoint(image_path=None):
    """Test the API endpoint."""
    print("\nTesting API endpoint...")
    
    # Use provided image or create test image
    if image_path and os.path.exists(image_path):
        with open(image_path, 'rb') as f:
            image_data = f.read()
        print(f"Using image: {image_path}")
    else:
        image_data = create_test_image()
        print("Using generated test image")
    
    try:
        # Test the API endpoint
        url = "http://127.0.0.1:8000/classify-image"
        files = {'image': ('test_image.jpg', image_data, 'image/jpeg')}
        
        response = requests.post(url, files=files, timeout=30)
        
        print(f"API Response status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("API test results:")
            print(f"  Category: {result.get('category')}")
            print(f"  Category confidence: {result.get('category_confidence', 0):.2f}")
            print(f"  Color: {result.get('color')}")
            print(f"  Color confidence: {result.get('color_confidence', 0):.2f}")
            print(f"  Success: {result.get('success')}")
            if result.get('error'):
                print(f"  Error: {result.get('error')}")
            return result.get('success', False)
        else:
            print(f"API Error: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("Could not connect to API server. Make sure the server is running on http://127.0.0.1:8000")
        return False
    except Exception as e:
        print(f"Error testing API: {e}")
        return False

def test_model_files():
    """Check if model files exist."""
    print("Checking model files...")
    
    model_dir = "YoloV8/models"
    type_model = os.path.join(model_dir, "yolov8n_clothing_type_object_detection.pt")
    color_model = os.path.join(model_dir, "yolov8n_color_custom_classification_best.pt")
    
    if os.path.exists(type_model):
        print(f"✓ Type model found: {type_model}")
        type_ok = True
    else:
        print(f"✗ Type model missing: {type_model}")
        type_ok = False
    
    if os.path.exists(color_model):
        print(f"✓ Color model found: {color_model}")
        color_ok = True
    else:
        print(f"✗ Color model missing: {color_model}")
        color_ok = False
    
    return type_ok and color_ok

def main():
    """Main test function."""
    print("=== Clothing Classification Test Suite ===\n")
    
    # Check command line argument for image path
    image_path = sys.argv[1] if len(sys.argv) > 1 else None
    
    # Test 1: Check model files
    models_ok = test_model_files()
    print()
    
    # Test 2: Test service directly
    if models_ok:
        service_ok = test_classification_service()
        print()
    else:
        print("Skipping service test due to missing models\n")
        service_ok = False
    
    # Test 3: Test API endpoint
    api_ok = test_api_endpoint(image_path)
    
    # Summary
    print("\n=== Test Summary ===")
    print(f"Model files: {'✓' if models_ok else '✗'}")
    print(f"Service test: {'✓' if service_ok else '✗'}")
    print(f"API test: {'✓' if api_ok else '✗'}")
    
    if models_ok and service_ok and api_ok:
        print("\n🎉 All tests passed! Classification system is working correctly.")
        return True
    else:
        print("\n❌ Some tests failed. Check the output above for details.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)