import os
import cv2
import numpy as np
from typing import Dict, Tuple, Optional, List
from ultralytics import YOLO
from PIL import Image
import io
import torch
from src.models.enums import Category


class ClothingClassificationService:
    """
    Service for classifying clothing items using trained YOLO models.
    Provides functionality to detect clothing type and color from images.
    """
    
    def __init__(self, models_path: str = "YoloV8/models"):
        """
        Initialize the classification service with trained YOLO models.
        
        Args:
            models_path: Path to the directory containing the trained model files
        """
        self.models_path = models_path
        self.type_model = None
        self.color_model = None
        
        # Color mapping from model predictions to hex colors
        self.color_mapping = {
            'black': '#000000',
            'white': '#FFFFFF', 
            'red': '#FF0000',
            'blue': '#0000FF',
            'green': '#008000',
            'yellow': '#FFFF00',
            'orange': '#FFA500',
            'purple': '#800080',
            'pink': '#FFC0CB',
            'brown': '#A52A2A',
            'gray': '#808080',
            'grey': '#808080',
            'navy': '#000080',
            'beige': '#F5F5DC',
            'khaki': '#F0E68C'
        }
        
        # Category mapping from model predictions to enum values
        self.category_mapping = {
            'shirt': Category.SHIRT,
            't-shirt': Category.TSHIRT,
            'tshirt': Category.TSHIRT,
            'jacket': Category.JACKET,
            'sweater': Category.SWEATER,
            'jeans': Category.JEANS,
            'pants': Category.PANTS,
            'shorts': Category.SHORTS,
            'short': Category.SHORTS,  # handle singular form
            'dress': Category.DRESS,   # proper dress mapping
            'shoes': Category.SHOES,
            'accessory': Category.ACCESSORY,
            'top': Category.SHIRT,  # fallback for generic tops
            'bottom': Category.PANTS,  # fallback for generic bottoms
        }
        
        self._load_models()
    
    def _load_models(self):
        """Load the trained YOLO models for classification."""
        try:
            # Load clothing type detection model
            type_model_path = os.path.join(self.models_path, "yolov8n_clothing_type_object_detection.pt")
            if os.path.exists(type_model_path):
                self.type_model = YOLO(type_model_path)
                print(f"Loaded clothing type model from: {type_model_path}")
            else:
                print(f"Warning: Type model not found at {type_model_path}")
            
            # Load color classification model  
            color_model_path = os.path.join(self.models_path, "yolov8n_color_custom_classification_best.pt")
            if os.path.exists(color_model_path):
                self.color_model = YOLO(color_model_path)
                print(f"Loaded color model from: {color_model_path}")
            else:
                print(f"Warning: Color model not found at {color_model_path}")
                
        except Exception as e:
            print(f"Error loading models: {e}")
            raise
    
    def _preprocess_image(self, image_data: bytes) -> np.ndarray:
        """
        Preprocess image data for YOLO inference.
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Preprocessed image array
        """
        try:
            # Convert bytes to PIL Image
            image = Image.open(io.BytesIO(image_data))
            
            # Convert to RGB if needed
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Convert PIL to numpy array
            image_array = np.array(image)
            
            return image_array
            
        except Exception as e:
            print(f"Error preprocessing image: {e}")
            raise ValueError(f"Failed to preprocess image: {e}")
    
    def classify_clothing_type(self, image_data: bytes) -> Tuple[Optional[Category], float]:
        """
        Classify the clothing type from an image.
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Tuple of (detected_category, confidence_score)
        """
        if not self.type_model:
            raise RuntimeError("Type classification model not loaded")
        
        try:
            # Preprocess image
            image = self._preprocess_image(image_data)
            
            # Run inference
            results = self.type_model(image)
            
            # Extract predictions
            if len(results) > 0 and len(results[0].boxes) > 0:
                # Get the detection with highest confidence
                boxes = results[0].boxes
                confidences = boxes.conf.cpu().numpy()
                class_ids = boxes.cls.cpu().numpy()
                
                # Get best detection
                best_idx = np.argmax(confidences)
                best_confidence = confidences[best_idx]
                best_class_id = int(class_ids[best_idx])
                
                # Map class ID to category name
                class_names = results[0].names  # Dictionary mapping class_id to class_name
                predicted_class = class_names.get(best_class_id, "unknown").lower()
                
                # Map to Category enum
                category = self.category_mapping.get(predicted_class)
                
                return category, float(best_confidence)
            
            return None, 0.0
            
        except Exception as e:
            print(f"Error in clothing type classification: {e}")
            return None, 0.0
    
    def classify_color(self, image_data: bytes) -> Tuple[Optional[str], float]:
        """
        Classify the dominant color from an image.
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Tuple of (hex_color, confidence_score)
        """
        if not self.color_model:
            raise RuntimeError("Color classification model not loaded")
        
        try:
            # Preprocess image
            image = self._preprocess_image(image_data)
            
            # Run inference
            results = self.color_model(image)
            
            # Extract predictions
            if len(results) > 0:
                # For classification model, get top prediction
                probs = results[0].probs
                if probs is not None:
                    top_class_id = probs.top1
                    confidence = probs.top1conf.item()
                    
                    # Map class ID to color name
                    class_names = results[0].names
                    predicted_color = class_names.get(top_class_id, "unknown").lower()
                    
                    # Map to hex color
                    hex_color = self.color_mapping.get(predicted_color, "#808080")  # Default to gray
                    
                    return hex_color, float(confidence)
            
            return None, 0.0
            
        except Exception as e:
            print(f"Error in color classification: {e}")
            return None, 0.0
    
    def classify_image_with_crop(self, image_data: bytes) -> Dict:
        """
        Perform clothing type detection, then color classification on the detected region.
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Dictionary containing classification results
        """
        try:
            # First, detect clothing type and get bounding box
            image = self._preprocess_image(image_data)
            type_results = self.type_model(image)
            
            results = {
                "category": None,
                "category_confidence": 0.0,
                "color": "#808080",  # Default gray
                "color_confidence": 0.0,
                "success": False,
                "cropped_region_used": False
            }
            
            # Extract clothing detection
            if len(type_results) > 0 and len(type_results[0].boxes) > 0:
                boxes = type_results[0].boxes
                confidences = boxes.conf.cpu().numpy()
                class_ids = boxes.cls.cpu().numpy()
                xyxy = boxes.xyxy.cpu().numpy()  # Bounding boxes
                
                # Get best detection
                best_idx = np.argmax(confidences)
                best_confidence = confidences[best_idx]
                best_class_id = int(class_ids[best_idx])
                best_box = xyxy[best_idx]  # [x1, y1, x2, y2]
                
                # Map class ID to category
                class_names = type_results[0].names
                predicted_class = class_names.get(best_class_id, "unknown").lower()
                category = self.category_mapping.get(predicted_class)
                
                results["category"] = category
                results["category_confidence"] = float(best_confidence)
                
                # Crop the detected clothing region for color analysis
                x1, y1, x2, y2 = map(int, best_box)
                
                # Ensure coordinates are within image bounds
                h, w = image.shape[:2]
                x1 = max(0, min(x1, w))
                y1 = max(0, min(y1, h))  
                x2 = max(0, min(x2, w))
                y2 = max(0, min(y2, h))
                
                # Crop the image to the detected clothing region
                cropped_image = image[y1:y2, x1:x2]
                
                if cropped_image.size > 0:
                    # Run color classification on the cropped region
                    color_results = self.color_model(cropped_image)
                    results["cropped_region_used"] = True
                    
                    if len(color_results) > 0:
                        probs = color_results[0].probs
                        if probs is not None:
                            top_class_id = probs.top1
                            color_confidence = probs.top1conf.item()
                            
                            class_names = color_results[0].names
                            predicted_color = class_names.get(top_class_id, "unknown").lower()
                            hex_color = self.color_mapping.get(predicted_color, "#808080")
                            
                            results["color"] = hex_color
                            results["color_confidence"] = float(color_confidence)
                
                results["success"] = True
                
            return results
            
        except Exception as e:
            return {
                "category": None,
                "category_confidence": 0.0,
                "color": "#808080",
                "color_confidence": 0.0,
                "success": False,
                "error": str(e),
                "cropped_region_used": False
            }

    def classify_image(self, image_data: bytes) -> Dict:
        """
        Perform both clothing type and color classification on an image.
        Uses cropped region detection for better color accuracy.
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Dictionary containing classification results
        """
        try:
            # Use the improved cropped region method
            results = self.classify_image_with_crop(image_data)
            
            # Improve "Others" color handling - fallback to full image if we get gray
            if results.get('color') == '#808080' and results.get('cropped_region_used'):
                # Try original method as fallback
                original_results = self._classify_image_original(image_data)
                
                # Use original color if it's not "Others" and has decent confidence
                if (original_results.get('color') != '#808080' and 
                    original_results.get('color_confidence', 0) > 0.3):
                    results['color'] = original_results['color']
                    results['color_confidence'] = original_results['color_confidence']
            
            # Clean up response - remove internal fields
            final_results = {
                "category": results['category'],
                "category_confidence": results['category_confidence'],
                "color": results['color'],
                "color_confidence": results['color_confidence'],
                "success": results['success']
            }
            
            if not results['success'] and 'error' in results:
                final_results['error'] = results['error']
                
            return final_results
            
        except Exception as e:
            return {
                "category": None,
                "category_confidence": 0.0,
                "color": "#808080",
                "color_confidence": 0.0,
                "success": False,
                "error": str(e)
            }

    def _classify_image_original(self, image_data: bytes) -> Dict:
        """
        Original classification method (full image) - kept as fallback for color.
        
        Args:
            image_data: Raw image bytes
            
        Returns:
            Dictionary containing classification results
        """
        results = {
            "category": None,
            "category_confidence": 0.0,
            "color": "#808080",
            "color_confidence": 0.0,
            "success": False
        }
        
        try:
            # Classify clothing type
            category, type_conf = self.classify_clothing_type(image_data)
            if category:
                results["category"] = category
                results["category_confidence"] = type_conf
                results["success"] = True
            
            # Classify color on full image
            color, color_conf = self.classify_color(image_data) 
            if color:
                results["color"] = color
                results["color_confidence"] = color_conf
                results["success"] = True
            
            return results
            
        except Exception as e:
            results["error"] = str(e)
            return results


# Global instance for dependency injection
_classification_service = None

def get_classification_service() -> ClothingClassificationService:
    """
    Dependency injection function for FastAPI.
    Returns a singleton instance of the classification service.
    """
    global _classification_service
    if _classification_service is None:
        _classification_service = ClothingClassificationService()
    return _classification_service