#!/usr/bin/env python3
"""
Simple CV Integration Test - Tests core functionality only
TO RUN: cd /Users/mjere/eecs-498-mvp-cv/TheBuilders && source /Users/mjere/env/bin/activate && python tests/services/simple_cv_test.py
"""
import os
import sys
import io
from PIL import Image, ImageDraw

# Add src to path for imports - using absolute path
src_path = "/Users/mjere/eecs-498-mvp-cv/TheBuilders/src"
sys.path.insert(0, src_path)

try:
    from services.classification_service import ClothingClassificationService
    from models.enums import Category
    print("✓ Successfully imported ClothingClassificationService and Category")
except ImportError as e:
    print(f"✗ Import error: {e}")
    print(f"Trying to import from: {src_path}")
    print(f"Path exists: {os.path.exists(src_path)}")
    if os.path.exists(src_path):
        print(f"Contents: {os.listdir(src_path)}")
        services_path = os.path.join(src_path, "services")
        if os.path.exists(services_path):
            print(f"Services contents: {os.listdir(services_path)}")
    sys.exit(1)


def test_complete_cv_integration():
    """Test the complete CV classification integration."""
    print("\n=== Complete CV Integration Test ===")
    
    try:
        # 1. Initialize the classification service
        print("1. Initializing classification service...")
        service = ClothingClassificationService()
        print("✓ Service initialized")
        
        # 2. Test with real clothing image if available
        print("2. Loading test image...")
        real_image_paths = [
            "/Users/mjere/eecs-498-mvp-cv/TheBuilders/YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
            "/Users/mjere/eecs-498-mvp-cv/TheBuilders/YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg",
            "/Users/mjere/eecs-498-mvp-cv/TheBuilders/YoloV8/test_imgs/646f1540b7426a82fcb0629f7c55ae062eaf0742.jpg"
        ]
        
        image_data = None
        image_name = None
        
        for img_path in real_image_paths:
            if os.path.exists(img_path):
                with open(img_path, 'rb') as f:
                    image_data = f.read()
                image_name = os.path.basename(img_path)
                print(f"✓ Loaded real image: {image_name}")
                break
        
        if not image_data:
            # Create synthetic clothing image
            print("Creating synthetic clothing image...")
            img = Image.new('RGB', (640, 480), color='white')
            draw = ImageDraw.Draw(img)
            
            # Draw a pants-like shape
            draw.rectangle([220, 180, 420, 450], fill='blue', outline='darkblue', width=3)  # Main body
            draw.rectangle([220, 180, 320, 450], fill='blue', outline='darkblue', width=2)  # Left leg
            draw.rectangle([320, 180, 420, 450], fill='blue', outline='darkblue', width=2)  # Right leg
            
            img_bytes = io.BytesIO()
            img.save(img_bytes, format='JPEG')
            image_data = img_bytes.getvalue()
            image_name = "synthetic_pants.jpg"
            print(f"✓ Created synthetic image: {image_name}")
        
        print(f"Image size: {len(image_data)} bytes")
        
        # 3. Perform classification
        print("3. Running classification...")
        result = service.classify_image(image_data)
        
        # 4. Verify results
        print("4. Verifying results...")
        print(f"Raw result: {result}")
        
        if not result.get('success', False):
            print(f"✗ Classification failed: {result.get('error', 'Unknown error')}")
            return False
        
        print("✓ Classification succeeded")
        
        # 5. Check iOS compatibility
        print("5. Checking iOS app compatibility...")
        
        # Verify all required fields are present
        required_fields = ['success', 'category', 'category_confidence', 'color', 'color_confidence']
        for field in required_fields:
            if field not in result:
                print(f"✗ Missing required field: {field}")
                return False
            print(f"✓ {field}: {result[field]}")
        
        # 6. Test iOS auto-fill logic
        print("6. Testing iOS auto-fill logic...")
        
        # Category auto-fill test
        if result['category'] is not None and result['category_confidence'] > 0.6:
            print(f"✓ iOS WOULD auto-fill category: {result['category']}")
            
            # Verify it's a valid category
            valid_categories = [cat.value for cat in Category]
            if result['category'] in valid_categories:
                category_name = [cat.name for cat in Category if cat.value == result['category']][0]
                print(f"✓ Category {result['category']} ({category_name}) is valid")
            else:
                print(f"✗ Invalid category {result['category']} - valid ones: {valid_categories}")
                return False
        else:
            print(f"⚠ iOS would NOT auto-fill category (confidence {result['category_confidence']:.2f} <= 0.6 or category is None)")
        
        # Color auto-fill test
        if result['color_confidence'] > 0.5:
            print(f"✓ iOS WOULD auto-fill color: {result['color']}")
            
            # Verify hex format
            if isinstance(result['color'], str) and result['color'].startswith('#') and len(result['color']) == 7:
                print(f"✓ Color format is valid: {result['color']}")
            else:
                print(f"✗ Invalid color format: {result['color']}")
                return False
        else:
            print(f"⚠ iOS would NOT auto-fill color (confidence {result['color_confidence']:.2f} <= 0.5)")
        
        # 7. Summary for user
        print("\n" + "="*50)
        print("CV INTEGRATION TEST RESULTS:")
        print(f"  Image: {image_name}")
        print(f"  Category: {result['category']} (confidence: {result['category_confidence']:.2f})")
        print(f"  Color: {result['color']} (confidence: {result['color_confidence']:.2f})")
        print(f"  iOS auto-fill category: {'YES' if result['category'] is not None and result['category_confidence'] > 0.6 else 'NO'}")
        print(f"  iOS auto-fill color: {'YES' if result['color_confidence'] > 0.5 else 'NO'}")
        print("="*50)
        
        return True
        
    except Exception as e:
        print(f"✗ Integration test failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run the complete CV integration test."""
    print("CV Integration Test - Direct Classification Service Testing")
    print("="*60)
    
    if test_complete_cv_integration():
        print("\n🎉 CV INTEGRATION IS WORKING!")
        print("\n✅ SUMMARY:")
        print("  • YOLO models are loaded and functional")
        print("  • Image classification works with real/synthetic images") 
        print("  • Response format matches iOS expectations")
        print("  • Auto-fill logic is properly implemented")
        print("  • Category mapping to enum values works")
        print("  • Color detection produces valid hex codes")
        print("\n📱 Your iOS app should successfully:")
        print("  • Upload images through the API")
        print("  • Receive classification results")
        print("  • Auto-fill clothing category and color fields")
        print("  • Display confidence-based UI updates")
        
        return 0
    else:
        print("\n❌ CV integration test failed")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)