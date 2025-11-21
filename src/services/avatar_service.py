from io import BytesIO


from minio import Minio
from google import genai
from PIL import Image


class AvatarService:
    def __init__(self, session_factory, *, minio: Minio):
        self._session_factory = session_factory
        
        self.bucket = "avatars"
        self._minio = minio

    def _call_gemini(self, image_bytes: bytes) -> bytes:
        """Call Google GenAI (Gemini image) to generate an avatar-like image.

        Uses the exact API form provided by the user: `genai.Client().models.generate_content`.
        Falls back to returning original bytes if `genai` or `PIL` is not available.
        """
        if not (genai and Image):
            return image_bytes

        try:
            inp = BytesIO(image_bytes)
            image = Image.open(inp)
        except Exception:
            return image_bytes

        # The client gets the API key from the environment variable `GEMINI_API_KEY`.
        client = genai.Client()

        # craft a prompt asking Gemini to produce an avatar-like image
        prompt = """You are generating a full-body 2D avatar from a real person photo.

            INPUT:
            - A full-body or partial-body photo of a real person.

            TASK:
            Create a complete full-body avatar of the same person as shown in the input image.

            STYLE REQUIREMENTS:
            - The avatar must have a realistic human texture.
            - Preserve natural skin texture, realistic shading, and lifelike facial details.
            - The output should look like a real human rendered in a clean, flat, 2D composition (not 3D, not cartoon).
            - Avoid stylized filters, painting effects, comic effects, anime style, or exaggerated features.

            IDENTITY PRESERVATION:
            - Preserve the person’s hairstyle accurately.
            - Preserve the person’s face shape, key facial features, and approximate expression.
            - Preserve the person’s body shape and body proportions.
            - Preserve the person’s approximate skin tone with realistic lighting.

            POSE CORRECTION:
            - If the original pose is rotated, occluded, or partially missing, correct it to a natural upright front-facing full-body pose.
            - Complete any missing parts of the body (legs, hands, feet, etc.) while maintaining realistic proportions.
            - Ensure both feet are visible and placed naturally.

            BACKGROUND:
            - Remove the background completely.
            - Output with a fully transparent background (RGBA).
            - No shadows, no floor, no environmental elements.

            CLOTHING:
            - Keep the high-level clothing type from the original photo (e.g., T-shirt, pants, coat), but simplify surface details.
            - Avoid logos, text, brand marks, or complex patterns.
            - Keep colors neutral and clean so that new outfits can be digitally applied later.

            OUTPUT REQUIREMENTS:
            - One full-body avatar image.
            - Realistic human texture preserved.
            - White Background.
            - Resolution around 512 × 512.
            - Center the avatar with even margins for future outfit overlays.
        """
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash-image",
                contents=[prompt, image]
            )
        except Exception as e:
            print(e)
            return image_bytes

        for part in response.parts:
            if part.inline_data:
                return part.inline_data.data


        # if no inline image returned, fallback to original bytes
        return image_bytes

    def generate_and_upload(self, user_id: int, image_bytes: bytes) -> str:
        """Generate an avatar-like image from input bytes and upload to MinIO.

        Returns the deterministic avatar URL (path) stored in the DB, e.g. `/avatars/user_123.png`.
        """
        generated = self._call_gemini(image_bytes)

        key = f"user_{user_id}"
        avatar_path = f"/{self.bucket}/{key}"
        
        # Uplaod to blob storage
        data = BytesIO(generated)
        data.seek(0)
        self._minio.put_object(self.bucket, key, data, length=len(generated), content_type="image/png")

        return avatar_path
