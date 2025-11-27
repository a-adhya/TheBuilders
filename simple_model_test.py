#!/usr/bin/env python3
"""
Simple test to verify your trained YOLO models are accessible.
"""
import os
import sys

def check_models():
    """Check if your trained model files exist and get basic info."""
    print("🔍 Checking Your Trained YOLO Models\n")
    
    models_dir = "YoloV8/models"
    expected_files = [
        "yolov8n_clothing_type_object_detection.pt",
        "yolov8n_color_custom_classification_best.pt"
    ]
    
    print("=== Model Files ===")
    all_found = True
    
    for model_file in expected_files:
        model_path = os.path.join(models_dir, model_file)
        if os.path.exists(model_path):
            size_mb = os.path.getsize(model_path) / (1024 * 1024)
            print(f"✅ {model_file}")
            print(f"   Path: {model_path}")
            print(f"   Size: {size_mb:.1f} MB")
            print()
        else:
            print(f"❌ Missing: {model_file}")
            all_found = False
    
    return all_found

def check_dependencies():
    """Check what's available without importing heavy packages."""
    print("=== Available Dependencies ===")
    
    # Test basic imports
    deps = {
        'os': True,  # Always available
        'sys': True,  # Always available
    }
    
    # Test optional imports
    optional_deps = ['PIL', 'numpy', 'torch', 'ultralytics']
    
    for dep in optional_deps:
        try:
            __import__(dep)
            deps[dep] = True
            print(f"✅ {dep}")
        except ImportError:
            deps[dep] = False
            print(f"❌ {dep}")
    
    return deps

def test_ultralytics_if_available():
    """Test ultralytics if available."""
    try:
        print("\n=== Testing Ultralytics ===")
        from ultralytics import YOLO
        print("✅ Ultralytics imported successfully")
        
        # Test your models
        models_dir = "YoloV8/models"
        models_to_test = [
            ("Clothing Type Model", "yolov8n_clothing_type_object_detection.pt"),
            ("Color Classification Model", "yolov8n_color_custom_classification_best.pt")
        ]
        
        for model_name, model_file in models_to_test:
            model_path = os.path.join(models_dir, model_file)
            
            if not os.path.exists(model_path):
                print(f"❌ {model_name}: File not found")
                continue
            
            try:
                print(f"\n📊 Testing {model_name}...")
                model = YOLO(model_path)
                print(f"✅ {model_name}: Loaded successfully!")
                
                # Get model info
                if hasattr(model, 'names'):
                    classes = list(model.names.values())
                    print(f"   Classes ({len(classes)}): {classes}")
                
                if hasattr(model, 'model'):
                    print(f"   Model type: {type(model.model).__name__}")
                
            except Exception as e:
                print(f"❌ {model_name}: Failed to load")
                print(f"   Error: {e}")
        
        return True
        
    except ImportError:
        print("\n⚠️  Ultralytics not available - install with:")
        print("   pip install ultralytics")
        return False
    except Exception as e:
        print(f"\n❌ Error testing ultralytics: {e}")
        return False

def main():
    """Main function."""
    print("=" * 60)
    print("  YOLO Models Integration Test")
    print("=" * 60)
    
    # Check model files
    models_exist = check_models()
    
    # Check dependencies
    deps = check_dependencies()
    
    # Test ultralytics if available
    if deps.get('ultralytics', False):
        ultralytics_works = test_ultralytics_if_available()
    else:
        ultralytics_works = False
    
    # Summary
    print("\n" + "=" * 60)
    print("=== SUMMARY ===")
    print(f"✅ Model files exist: {models_exist}")
    print(f"✅ Dependencies available: {sum(deps.values())}/{len(deps)}")
    print(f"✅ Ultralytics works: {ultralytics_works}")
    
    if models_exist and ultralytics_works:
        print("\n🎉 SUCCESS: Your trained models are ready!")
        print("\nNext steps:")
        print("1. Install FastAPI: pip install fastapi uvicorn")
        print("2. Start the server: python -m uvicorn src.api.server:app --reload")
        print("3. Test the /classify-image endpoint")
        
    elif models_exist:
        print("\n📝 TODO: Install ultralytics to use your models")
        print("   pip install ultralytics torch torchvision")
        
    else:
        print("\n❌ Model files missing - check your Jupyter notebook output")

if __name__ == "__main__":
    main()