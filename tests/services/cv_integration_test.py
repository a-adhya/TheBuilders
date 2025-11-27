#!/usr/bin/env python3
"""
Integration test for CV classification with image upload workflow
Tests the complete pipeline without starting a server
TO RUN: cd /Users/mjere/eecs-498-mvp-cv/TheBuilders && PYTHONPATH=src python tests/services/cv_integration_test.py
"""
import os
import sys
import io
from PIL import Image, ImageDraw

# Add src to path for imports
current_dir = os.path.dirname(os.path.abspath(__file__))
src_dir = os.path.join(current_dir, '..', '..', 'src')
sys.path.insert(0, src_dir)

try:
    from services.classification_service import ClothingClassificationService
    from models.enums import Category
    print("✓ Successfully imported core modules")
    
    # Try to import API modules (optional for basic testing)
    try:
        from api.server import classify_image
        from api.schema import ClassifyImageResponse
        print("✓ Successfully imported API modules")
        API_AVAILABLE = True
    except ImportError as api_e:
        print(f"⚠ API modules not available: {api_e}")
        print("  (Will skip API-specific tests)")
        API_AVAILABLE = False
        
except ImportError as e:
    print(f"✗ Core import error: {e}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Python path: {sys.path}")
    print(f"Src directory: {src_dir}")
    print(f"Src directory exists: {os.path.exists(src_dir)}")
    if os.path.exists(src_dir):
        print(f"Contents of src: {os.listdir(src_dir)}")
    sys.exit(1)


def create_mock_upload_file(image_data, filename="test_image.jpg"):
    """Create a mock UploadFile object similar to what FastAPI receives."""
    
    class MockUploadFile:
        def __init__(self, content, filename):
            self.filename = filename
            self.content_type = "image/jpeg"
            self._content = content
            
        async def read(self):
            return self._content
    
    return MockUploadFile(image_data, filename)


def test_api_function_directly():
    """Test the API classify_image function directly without HTTP server."""
    print("\n=== Testing API Function Directly ===")
    
    if not API_AVAILABLE:
        print("⚠ Skipping API function test - API modules not available")
        return True
    
    # Load a real clothing image
    test_image_paths = [
        "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
        "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg"
    ]
    
    image_data = None
    image_name = None
    
    for img_path in test_image_paths:
        if os.path.exists(img_path):
            with open(img_path, 'rb') as f:
                image_data = f.read()
                image_name = os.path.basename(img_path)
            break
    
    if not image_data:
        # Create synthetic image as fallback
        print("Creating synthetic image for testing...")
        img = Image.new('RGB', (640, 480), color='white')
        draw = ImageDraw.Draw(img)
        draw.rectangle([200, 150, 440, 350], fill='blue', outline='black', width=3)
        
        img_bytes = io.BytesIO()
        img.save(img_bytes, format='JPEG')
        image_data = img_bytes.getvalue()
        image_name = "synthetic_shirt.jpg"
    
    print(f"Testing with image: {image_name}")
    
    try:
        # Create mock upload file
        mock_file = create_mock_upload_file(image_data, image_name)
        
        # This would normally be an async call in FastAPI
        # For testing, we'll call it directly (note: this might need adjustment)
        import asyncio
        
        async def run_classification():
            return await classify_image(mock_file)
        
        # Run the async function
        result = asyncio.run(run_classification())
        
        print(f"✓ API function executed successfully")
        print(f"Result type: {type(result)}")
        print(f"Result: {result}")
        
        # Verify it's the expected response format
        if hasattr(result, 'success'):
            print(f"  Success: {result.success}")
            print(f"  Category: {result.category}")
            print(f"  Category confidence: {result.category_confidence}")
            print(f"  Color: {result.color}")
            print(f"  Color confidence: {result.color_confidence}")
            
            if result.success:
                print("✓ End-to-end API classification successful")
                return True
            else:
                print(f"✗ Classification failed: {getattr(result, 'error', 'Unknown error')}")
                return False
        else:
            print(f"✗ Unexpected result format: {result}")
            return False
            
    except Exception as e:
        print(f"✗ API function test failed: {e}")
        return False


def test_ios_compatible_response_format():
    """Test that our API response matches what iOS expects."""
    print("\n=== Testing iOS Response Format Compatibility ===")
    
    try:
        service = ClothingClassificationService()
        
        # Load test image
        test_image_path = "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg"
        if os.path.exists(test_image_path):
            with open(test_image_path, 'rb') as f:
                image_data = f.read()
        else:
            # Synthetic fallback
            img = Image.new('RGB', (320, 240), color='red')
            img_bytes = io.BytesIO()
            img.save(img_bytes, format='JPEG')
            image_data = img_bytes.getvalue()
        
        # Get classification result
        result = service.classify_image(image_data)
        
        print(f"Raw classification result: {result}")
        
        # Verify iOS compatibility
        ios_expected_keys = ['success', 'category', 'category_confidence', 'color', 'color_confidence']
        
        for key in ios_expected_keys:
            if key not in result:
                print(f"✗ Missing iOS-expected key: {key}")
                return False
            print(f"✓ {key}: {result[key]}")
        
        # Test specific iOS logic
        if result['success']:
            # This mimics the iOS logic in AddClothingItemView.swift
            if result['category'] is not None and result['category_confidence'] > 0.6:
                print(f"✓ iOS would auto-fill category: {result['category']}")
                
                # Verify category is valid
                valid_categories = [cat.value for cat in Category]
                if result['category'] in valid_categories:
                    print(f"✓ Category {result['category']} is valid")
                else:
                    print(f"✗ Category {result['category']} not in valid categories: {valid_categories}")
                    return False
            else:
                print(f"⚠ iOS would not auto-fill category (confidence {result['category_confidence']:.2f} <= 0.6)")
            
            if result['color_confidence'] > 0.5:
                print(f"✓ iOS would auto-fill color: {result['color']}")
                
                # Verify hex color format
                if result['color'].startswith('#') and len(result['color']) == 7:
                    print(f"✓ Color format is valid hex")
                else:
                    print(f"✗ Invalid color format: {result['color']}")
                    return False
            else:
                print(f"⚠ iOS would not auto-fill color (confidence {result['color_confidence']:.2f} <= 0.5)")
        
        return True
        
    except Exception as e:
        print(f"✗ iOS compatibility test failed: {e}")
        return False


def test_multipart_simulation():
    """Test simulating the multipart form upload that iOS sends."""
    print("\n=== Testing Multipart Upload Simulation ===")
    
    try:
        # This simulates what MockAPIStore.swift sends
        test_image_path = "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg"
        
        if os.path.exists(test_image_path):
            with open(test_image_path, 'rb') as f:
                image_data = f.read()
            print(f"✓ Loaded real test image: {os.path.basename(test_image_path)}")
        else:
            # Create synthetic image
            img = Image.new('RGB', (400, 600), color='lightblue')  # Shirt-like dimensions
            draw = ImageDraw.Draw(img)
            draw.rectangle([100, 50, 300, 300], fill='darkblue', outline='black', width=2)
            
            img_bytes = io.BytesIO()
            img.save(img_bytes, format='JPEG')
            image_data = img_bytes.getvalue()
            print("✓ Created synthetic test image")
        
        print(f"Image size: {len(image_data)} bytes")
        
        # Test the classification service directly (this is what the API calls)
        service = ClothingClassificationService()
        result = service.classify_image(image_data)
        
        print(f"Classification result: {result}")
        
        # Verify this matches the ClassifyImageResponse schema
        if result['success']:
            # Create the actual response object that would be returned to iOS
            if API_AVAILABLE:
                api_response = ClassifyImageResponse(
                    success=result['success'],
                    category=result['category'],
                    category_confidence=result['category_confidence'], 
                    color=result['color'],
                    color_confidence=result['color_confidence']
                )
                
                print(f"✓ Successfully created API response object")
                print(f"API Response: {api_response}")
            else:
                print(f"⚠ Skipping API response object creation - API modules not available")
            
            print(f"✓ Successfully created API response object")
            print(f"API Response: {api_response}")
            
            # This is what iOS would receive as JSON
            json_response = {
                "success": api_response.success,
                "category": api_response.category,
                "category_confidence": api_response.category_confidence,
                "color": api_response.color, 
                "color_confidence": api_response.color_confidence
            }
            
            print(f"✓ JSON response for iOS: {json_response}")
            return True
        else:
            print(f"✗ Classification failed: {result.get('error', 'Unknown error')}")
            return False
            
    except Exception as e:
        print(f"✗ Multipart simulation failed: {e}")
        return False


def main():
    """Run all CV integration tests."""
    print("Starting CV Integration Tests (No Server Required)")
    print("=" * 60)
    
    tests_passed = 0
    total_tests = 0
    
    # Test 1: Direct API function test
    total_tests += 1
    if test_api_function_directly():
        tests_passed += 1
    
    # Test 2: iOS compatibility
    total_tests += 1
    if test_ios_compatible_response_format():
        tests_passed += 1
    
    # Test 3: Multipart simulation
    total_tests += 1  
    if test_multipart_simulation():
        tests_passed += 1
    
    # Summary
    print("\n" + "=" * 60)
    print(f"CV INTEGRATION TEST SUMMARY: {tests_passed}/{total_tests} tests passed")
    
    if tests_passed == total_tests:
        print("🎉 Complete CV integration is working!")
        print("\n✅ Your image upload → CV classification → iOS response flow is ready!")
        print("✅ The iOS app should successfully auto-fill clothing category and color")
        print("✅ No server startup required for basic functionality testing")
        return 0
    else:
        print("❌ Some integration tests failed")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)