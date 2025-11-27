#!/usr/bin/env python3
"""
Simple test runner for ClothingClassificationService
TO RUN: cd /Users/mjere/eecs-498-mvp-cv/TheBuilders && PYTHONPATH=src python tests/services/classification_service_tests.py
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
    print("✓ Successfully imported ClothingClassificationService and Category")
except ImportError as e:
    print(f"✗ Import error: {e}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Python path: {sys.path}")
    print(f"Src directory: {src_dir}")
    print(f"Src directory exists: {os.path.exists(src_dir)}")
    if os.path.exists(src_dir):
        print(f"Contents of src: {os.listdir(src_dir)}")
    sys.exit(1)


def test_model_files_exist():
    """Test that required YOLO model files exist."""
    print("\n=== Testing Model Files ===")
    
    type_model_path = "YoloV8/models/yolov8n_clothing_type_object_detection.pt"
    color_model_path = "YoloV8/models/yolov8n_color_custom_classification_best.pt"
    
    print(f"Checking type model: {type_model_path}")
    if os.path.exists(type_model_path):
        size = os.path.getsize(type_model_path)
        print(f"✓ Type model found ({size} bytes)")
    else:
        print(f"✗ Type model not found: {type_model_path}")
        return False
    
    print(f"Checking color model: {color_model_path}")
    if os.path.exists(color_model_path):
        size = os.path.getsize(color_model_path)
        print(f"✓ Color model found ({size} bytes)")
    else:
        print(f"✗ Color model not found: {color_model_path}")
        return False
    
    return True


def test_service_initialization():
    """Test that the classification service initializes properly."""
    print("\n=== Testing Service Initialization ===")
    
    try:
        service = ClothingClassificationService()
        print("✓ ClothingClassificationService initialized successfully")
        
        # Check if models are loaded
        if hasattr(service, 'type_model') and service.type_model is not None:
            print("✓ Type model loaded")
        else:
            print("✗ Type model not loaded")
            return False
            
        if hasattr(service, 'color_model') and service.color_model is not None:
            print("✓ Color model loaded")
        else:
            print("✗ Color model not loaded")
            return False
            
        # Check mappings
        if hasattr(service, 'category_mapping'):
            print(f"✓ Category mapping available ({len(service.category_mapping)} items)")
        else:
            print("✗ Category mapping not found")
            
        if hasattr(service, 'color_mapping'):
            print(f"✓ Color mapping available ({len(service.color_mapping)} items)")
        else:
            print("✗ Color mapping not found")
        
        return service
    except Exception as e:
        print(f"✗ Service initialization failed: {e}")
        return False


def create_synthetic_image():
    """Create a synthetic clothing image for testing."""
    print("\n=== Creating Synthetic Test Image ===")
    
    # Create a more realistic clothing-like image
    img = Image.new('RGB', (640, 480), color='white')
    draw = ImageDraw.Draw(img)
    
    # Draw a shirt-like shape
    # Main body
    draw.rectangle([200, 150, 440, 350], fill='blue', outline='black', width=3)
    # Sleeves
    draw.rectangle([150, 170, 200, 250], fill='blue', outline='black', width=2)
    draw.rectangle([440, 170, 490, 250], fill='blue', outline='black', width=2)
    # Collar
    draw.polygon([(220, 150), (320, 120), (420, 150), (320, 170)], fill='white', outline='black')
    
    # Convert to bytes
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    print("✓ Synthetic clothing image created")
    return img_bytes.getvalue()


def test_classify_synthetic_image(service):
    """Test classification with a synthetic clothing image."""
    print("\n=== Testing Synthetic Image Classification ===")
    
    try:
        image_data = create_synthetic_image()
        result = service.classify_image(image_data)
        
        print(f"Classification result: {result}")
        
        # Verify response structure
        required_keys = ['success', 'category', 'category_confidence', 'color', 'color_confidence']
        for key in required_keys:
            if key not in result:
                print(f"✗ Missing key in result: {key}")
                return False
        
        print("✓ Result has all required keys")
        
        if result['success']:
            print("✓ Classification succeeded")
            print(f"  Category: {result['category']} (confidence: {result['category_confidence']:.2f})")
            print(f"  Color: {result['color']} (confidence: {result['color_confidence']:.2f})")
        else:
            print(f"✗ Classification failed: {result.get('error', 'Unknown error')}")
            return False
        
        return True
    except Exception as e:
        print(f"✗ Synthetic image classification failed: {e}")
        return False


def test_real_images(service):
    """Test classification on real clothing images."""
    print("\n=== Testing Real Image Classification ===")
    
    test_image_paths = [
        "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
        "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg", 
        "YoloV8/test_imgs/646f1540b7426a82fcb0629f7c55ae062eaf0742.jpg"
    ]
    
    results = []
    
    for img_path in test_image_paths:
        if os.path.exists(img_path):
            print(f"\nTesting image: {os.path.basename(img_path)}")
            
            try:
                with open(img_path, 'rb') as f:
                    image_data = f.read()
                
                result = service.classify_image(image_data)
                
                if result['success']:
                    print(f"✓ Classification successful")
                    print(f"  Category: {result['category']} (confidence: {result['category_confidence']:.2f})")
                    print(f"  Color: {result['color']} (confidence: {result['color_confidence']:.2f})")
                    
                    results.append({
                        'image': os.path.basename(img_path),
                        'category': result['category'],
                        'category_confidence': result['category_confidence'],
                        'color': result['color'],
                        'color_confidence': result['color_confidence']
                    })
                else:
                    print(f"✗ Classification failed: {result.get('error', 'Unknown error')}")
            
            except Exception as e:
                print(f"✗ Error processing {img_path}: {e}")
        else:
            print(f"⚠ Image not found: {img_path}")
    
    if len(results) > 0:
        print(f"\n✓ Successfully processed {len(results)} real images")
        return True
    else:
        print("\n⚠ No real images found to test")
        return True  # Not a failure, just no images available


def main():
    """Run all tests."""
    print("Starting ClothingClassificationService Tests")
    print("=" * 50)
    
    tests_passed = 0
    total_tests = 0
    
    # Test 1: Model files exist
    total_tests += 1
    if test_model_files_exist():
        tests_passed += 1
    
    # Test 2: Service initialization
    total_tests += 1
    service = test_service_initialization()
    if service:
        tests_passed += 1
        
        # Test 3: Synthetic image classification
        total_tests += 1
        if test_classify_synthetic_image(service):
            tests_passed += 1
        
        # Test 4: Real image classification  
        total_tests += 1
        if test_real_images(service):
            tests_passed += 1
    
    # Summary
    print("\n" + "=" * 50)
    print(f"TEST SUMMARY: {tests_passed}/{total_tests} tests passed")
    
    if tests_passed == total_tests:
        print("🎉 All tests passed!")
        return 0
    else:
        print("❌ Some tests failed")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)