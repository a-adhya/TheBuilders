#!/usr/bin/env python3
"""
Quick test to check if your YOLO models exist and can be loaded.
"""
import os
import sys

def check_python_env():
    """Check basic Python environment."""
    print("=== Python Environment Check ===")
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print()

def check_model_files():
    """Check if your trained model files exist."""
    print("=== Model Files Check ===")
    
    models_dir = "YoloV8/models"
    expected_files = [
        "yolov8n_clothing_type_object_detection.pt",
        "yolov8n_color_custom_classification_best.pt"
    ]
    
    all_found = True
    
    for model_file in expected_files:
        model_path = os.path.join(models_dir, model_file)
        if os.path.exists(model_path):
            size_mb = os.path.getsize(model_path) / (1024 * 1024)
            print(f"✅ Found: {model_file} ({size_mb:.1f} MB)")
        else:
            print(f"❌ Missing: {model_file}")
            all_found = False
    
    return all_found

def check_dependencies():
    """Check if required dependencies are available."""
    print("\n=== Dependencies Check ===")
    
    required_packages = {
        'PIL': 'pillow',
        'numpy': 'numpy', 
        'ultralytics': 'ultralytics',
        'torch': 'torch'
    }
    
    available = []
    missing = []
    
    for module_name, package_name in required_packages.items():
        try:
            __import__(module_name)
            print(f"✅ {package_name} is available")
            available.append(package_name)
        except ImportError:
            print(f"❌ {package_name} is missing")
            missing.append(package_name)
    
    return available, missing

def test_basic_yolo():
    """Test basic YOLO functionality if ultralytics is available."""
    print("\n=== Basic YOLO Test ===")
    
    try:
        from ultralytics import YOLO
        print("✅ Ultralytics import successful")
        
        # Try to load a small pretrained model (this will download if needed)
        try:
            model = YOLO('yolov8n.pt')
            print("✅ YOLO model loading works")
            return True
        except Exception as e:
            print(f"⚠️  YOLO model loading failed: {e}")
            return False
            
    except ImportError as e:
        print(f"❌ Cannot import ultralytics: {e}")
        return False

def test_your_models():
    """Test loading your specific trained models."""
    print("\n=== Your Trained Models Test ===")
    
    try:
        from ultralytics import YOLO
        
        models_dir = "YoloV8/models"
        models_to_test = [
            ("Type Model", "yolov8n_clothing_type_object_detection.pt"),
            ("Color Model", "yolov8n_color_custom_classification_best.pt")
        ]
        
        results = {}
        
        for model_name, model_file in models_to_test:
            model_path = os.path.join(models_dir, model_file)
            
            if not os.path.exists(model_path):
                print(f"❌ {model_name}: File not found - {model_path}")
                results[model_name] = False
                continue
            
            try:
                model = YOLO(model_path)
                print(f"✅ {model_name}: Loaded successfully")
                print(f"   Classes: {list(model.names.values())}")
                results[model_name] = True
                
            except Exception as e:
                print(f"❌ {model_name}: Failed to load - {e}")
                results[model_name] = False
        
        return results
        
    except ImportError:
        print("❌ Cannot test models - ultralytics not available")
        return {}

def main():
    """Main test function."""
    print("🔍 YOLO Models Integration Test\n")
    
    # Basic checks
    check_python_env()
    models_exist = check_model_files()
    available, missing = check_dependencies()
    
    # If we have ultralytics, test YOLO functionality
    if 'ultralytics' in available:
        basic_yolo_works = test_basic_yolo()
        if basic_yolo_works and models_exist:
            model_results = test_your_models()
        else:
            model_results = {}
    else:
        basic_yolo_works = False
        model_results = {}
    
    # Summary
    print("\n" + "="*50)
    print("=== SUMMARY ===")
    print(f"Model files exist: {'✅' if models_exist else '❌'}")
    print(f"Dependencies available: {len(available)}/{len(available) + len(missing)}")
    print(f"Basic YOLO works: {'✅' if basic_yolo_works else '❌'}")
    
    if model_results:
        for model_name, works in model_results.items():
            print(f"{model_name} works: {'✅' if works else '❌'}")
    
    # Instructions
    if missing:
        print(f"\n📝 To install missing dependencies:")
        print(f"pip install {' '.join(missing)}")
    
    if models_exist and 'ultralytics' in available and basic_yolo_works:
        print(f"\n🎉 Your models are ready for testing!")
        print(f"Next step: Test the classification service")
    else:
        print(f"\n⚠️  Some issues found. Fix the above before proceeding.")

if __name__ == "__main__":
    main()