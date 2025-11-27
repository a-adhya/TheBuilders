#!/usr/bin/env python3
"""
Complete integration test for the clothing classification system.
Tests the full end-to-end workflow from image upload to classification results.
"""
import os
import sys
import time
import requests
import subprocess
import threading
import signal
from io import BytesIO
import json

# Add src to Python path
sys.path.insert(0, 'src')

try:
    from PIL import Image, ImageDraw
    import numpy as np
    HAS_IMAGING = True
except ImportError:
    HAS_IMAGING = False
    print("Warning: PIL/numpy not available - will use basic tests only")

class IntegrationTester:
    """Comprehensive integration tester for the clothing classification system."""
    
    def __init__(self):
        self.server_process = None
        self.base_url = "http://127.0.0.1:8000"
        self.test_results = {
            'models': False,
            'service': False,
            'server': False,
            'api_endpoint': False,
            'ios_integration': False
        }
        
    def log(self, message, level="INFO"):
        """Log messages with timestamps."""
        timestamp = time.strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")
    
    def check_model_files(self):
        """Verify model files exist and are valid."""
        self.log("Checking model files...")
        
        model_paths = [
            "YoloV8/models/yolov8n_clothing_type_object_detection.pt",
            "YoloV8/models/yolov8n_color_custom_classification_best.pt"
        ]
        
        for model_path in model_paths:
            if not os.path.exists(model_path):
                self.log(f"❌ Model file missing: {model_path}", "ERROR")
                return False
            
            size_mb = os.path.getsize(model_path) / (1024 * 1024)
            self.log(f"✅ Found model: {os.path.basename(model_path)} ({size_mb:.1f} MB)")
        
        self.test_results['models'] = True
        return True
    
    def test_classification_service(self):
        """Test the classification service directly."""
        self.log("Testing classification service...")
        
        try:
            from src.services.classification_service import ClothingClassificationService
            
            service = ClothingClassificationService()
            
            # Test with real clothing images
            test_images = [
                "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
                "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg",
                "YoloV8/test_imgs/646f1540b7426a82fcb0629f7c55ae062eaf0742.jpg"
            ]
            
            success_count = 0
            
            for img_path in test_images:
                if os.path.exists(img_path):
                    self.log(f"Testing image: {os.path.basename(img_path)}")
                    
                    with open(img_path, 'rb') as f:
                        image_data = f.read()
                    
                    result = service.classify_image(image_data)
                    
                    if result.get('success'):
                        success_count += 1
                        self.log(f"  ✅ Category: {result.get('category')} (conf: {result.get('category_confidence', 0):.2f})")
                        self.log(f"  ✅ Color: {result.get('color')} (conf: {result.get('color_confidence', 0):.2f})")
                    else:
                        self.log(f"  ❌ Classification failed: {result.get('error')}", "ERROR")
            
            if success_count > 0:
                self.log(f"✅ Service test passed: {success_count}/{len(test_images)} images classified")
                self.test_results['service'] = True
                return True
            else:
                self.log("❌ Service test failed: No images classified successfully", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Service test failed: {e}", "ERROR")
            return False
    
    def start_api_server(self):
        """Start the FastAPI server in background."""
        self.log("Starting API server...")
        
        try:
            # Check if uvicorn is available
            import uvicorn
        except ImportError:
            self.log("Installing FastAPI dependencies...")
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'fastapi', 'uvicorn', 'python-multipart'])
        
        try:
            # Start server in background
            cmd = [sys.executable, '-m', 'uvicorn', 'src.api.server:app', '--host', '127.0.0.1', '--port', '8000']
            self.server_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid  # Create new process group for clean shutdown
            )
            
            # Wait for server to start
            max_retries = 30
            for i in range(max_retries):
                try:
                    response = requests.get(f"{self.base_url}/docs", timeout=1)
                    if response.status_code == 200:
                        self.log("✅ API server started successfully")
                        self.test_results['server'] = True
                        return True
                except:
                    time.sleep(1)
            
            self.log("❌ API server failed to start", "ERROR")
            return False
            
        except Exception as e:
            self.log(f"❌ Failed to start API server: {e}", "ERROR")
            return False
    
    def test_api_endpoints(self):
        """Test API endpoints with real images."""
        self.log("Testing API endpoints...")
        
        # Test health endpoint
        try:
            response = requests.get(f"{self.base_url}/health")
            if response.status_code == 200:
                self.log("✅ Health endpoint working")
            else:
                self.log(f"❌ Health endpoint failed: {response.status_code}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Health endpoint error: {e}", "ERROR")
            return False
        
        # Test classification endpoint
        test_images = [
            "YoloV8/test_imgs/1985f5d7bbe98b597e7e013020842e97f64553fb.jpg",
            "YoloV8/test_imgs/532b64d7fab3702507f1fdc7412d24a1b61d9d47.jpg"
        ]
        
        success_count = 0
        
        for img_path in test_images:
            if os.path.exists(img_path):
                self.log(f"Testing API with image: {os.path.basename(img_path)}")
                
                try:
                    with open(img_path, 'rb') as f:
                        files = {'image': (os.path.basename(img_path), f, 'image/jpeg')}
                        response = requests.post(f"{self.base_url}/classify-image", files=files, timeout=30)
                    
                    if response.status_code == 200:
                        result = response.json()
                        self.log(f"  ✅ API Response: Category={result.get('category')}, Color={result.get('color')}")
                        success_count += 1
                    else:
                        self.log(f"  ❌ API Error: {response.status_code} - {response.text}", "ERROR")
                        
                except Exception as e:
                    self.log(f"  ❌ API Request failed: {e}", "ERROR")
        
        if success_count > 0:
            self.log(f"✅ API endpoint test passed: {success_count}/{len(test_images)} requests successful")
            self.test_results['api_endpoint'] = True
            return True
        else:
            self.log("❌ API endpoint test failed", "ERROR")
            return False
    
    def test_ios_integration_readiness(self):
        """Test if the system is ready for iOS integration."""
        self.log("Testing iOS integration readiness...")
        
        try:
            # Test if the API can handle the expected iOS request format
            if not HAS_IMAGING:
                self.log("❌ PIL not available for iOS integration test", "ERROR")
                return False
            
            # Create a test image similar to what iOS would send
            img = Image.new('RGB', (640, 480), color='blue')
            draw = ImageDraw.Draw(img)
            draw.rectangle([200, 100, 440, 300], fill='red', outline='black', width=3)
            
            img_bytes = BytesIO()
            img.save(img_bytes, format='JPEG')
            img_data = img_bytes.getvalue()
            
            # Test multipart/form-data upload (iOS format)
            files = {'image': ('test_image.jpg', img_data, 'image/jpeg')}
            response = requests.post(f"{self.base_url}/classify-image", files=files, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                required_fields = ['category', 'color', 'category_confidence', 'color_confidence']
                
                if all(field in result for field in required_fields):
                    self.log("✅ iOS integration format compatible")
                    self.test_results['ios_integration'] = True
                    return True
                else:
                    missing = [f for f in required_fields if f not in result]
                    self.log(f"❌ Missing required fields for iOS: {missing}", "ERROR")
                    return False
            else:
                self.log(f"❌ iOS integration test failed: {response.status_code}", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ iOS integration test error: {e}", "ERROR")
            return False
    
    def stop_server(self):
        """Stop the API server."""
        if self.server_process:
            self.log("Stopping API server...")
            try:
                # Kill the process group to ensure clean shutdown
                os.killpg(os.getpgid(self.server_process.pid), signal.SIGTERM)
                self.server_process.wait(timeout=5)
            except:
                try:
                    os.killpg(os.getpgid(self.server_process.pid), signal.SIGKILL)
                except:
                    pass
            self.server_process = None
    
    def run_full_integration_test(self):
        """Run the complete integration test suite."""
        self.log("=" * 60)
        self.log("STARTING FULL INTEGRATION TEST")
        self.log("=" * 60)
        
        try:
            # Test 1: Model files
            if not self.check_model_files():
                self.log("❌ Model files test failed - cannot continue", "ERROR")
                return False
            
            # Test 2: Classification service
            if not self.test_classification_service():
                self.log("❌ Classification service test failed", "ERROR")
                return False
            
            # Test 3: Start API server
            if not self.start_api_server():
                self.log("❌ API server startup failed", "ERROR")
                return False
            
            # Test 4: API endpoints
            if not self.test_api_endpoints():
                self.log("❌ API endpoint test failed", "ERROR")
                return False
            
            # Test 5: iOS integration readiness
            if not self.test_ios_integration_readiness():
                self.log("❌ iOS integration test failed", "ERROR")
                return False
            
            self.log("=" * 60)
            self.log("🎉 ALL INTEGRATION TESTS PASSED!")
            self.log("=" * 60)
            
            # Print summary
            self.print_test_summary()
            return True
            
        except KeyboardInterrupt:
            self.log("Test interrupted by user", "WARNING")
            return False
        except Exception as e:
            self.log(f"Unexpected error during integration test: {e}", "ERROR")
            return False
        finally:
            self.stop_server()
    
    def print_test_summary(self):
        """Print a summary of all test results."""
        self.log("\n=== INTEGRATION TEST SUMMARY ===")
        
        test_names = {
            'models': 'Model Files',
            'service': 'Classification Service',
            'server': 'API Server Startup',
            'api_endpoint': 'API Endpoints',
            'ios_integration': 'iOS Integration Readiness'
        }
        
        for key, name in test_names.items():
            status = "✅ PASS" if self.test_results[key] else "❌ FAIL"
            self.log(f"  {name}: {status}")
        
        total_passed = sum(self.test_results.values())
        total_tests = len(self.test_results)
        
        self.log(f"\nOverall: {total_passed}/{total_tests} tests passed")
        
        if total_passed == total_tests:
            self.log("🚀 System ready for production use!")
        else:
            self.log("⚠️  Some issues need to be resolved before deployment.")


def main():
    """Run the full integration test."""
    tester = IntegrationTester()
    
    try:
        success = tester.run_full_integration_test()
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        tester.stop_server()
        return 1
    except Exception as e:
        print(f"Fatal error: {e}")
        tester.stop_server()
        return 1


if __name__ == "__main__":
    sys.exit(main())