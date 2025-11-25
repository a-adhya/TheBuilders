from io import BytesIO


from minio import Minio
from google import genai
from PIL import Image
from db.driver import session_scope
from db.garment_store import MakeGarmentStore


class AvatarGenerationError(RuntimeError):
    """Raised when avatar generation (Gemini) fails or returned data is invalid."""


class AvatarService:
    def __init__(self, session_factory, *, minio: Minio):
        self._session_factory = session_factory
        
        self.bucket = "avatars"
        self._minio = minio

    def _call_gemini(self, image_bytes: bytes, requested_descriptions: list[str] | None = None) -> bytes:
        """Call Google GenAI (Gemini image) to generate an avatar-like image.

        Uses the exact API form provided by the user: `genai.Client().models.generate_content`.
        On any failure this raises `AvatarGenerationError` — the caller should handle it.
        """

        try:
            inp = BytesIO(image_bytes)
            image = Image.open(inp)
        except Exception as e:
            raise AvatarGenerationError("failed to open input image") from e

        # The client gets the API key from the environment variable `GEMINI_API_KEY`.
        client = genai.Client()

        # craft a prompt asking Gemini to produce an avatar-like image
        # Insert only the shared prompt and the configurable CLOTHING section.
        prompt = (
            self._shared_avatar_prompt()
            + "\n\n"
            + self._clothing_section(requested_descriptions)
        )
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash-image",
                contents=[prompt, image]
            )
        except Exception as e:
            raise AvatarGenerationError("gemini generation failed") from e

        for part in response.parts:
            if part.inline_data:
                return part.inline_data.data

        # No inline image returned — treat this as a generation failure
        raise AvatarGenerationError("no image returned by Gemini")

    def _shared_avatar_prompt(self) -> str:
        """Return the shared parts of the avatar-generation prompt.

        This covers INPUT, TASK, STYLE, IDENTITY, POSE, BACKGROUND guidance and
        high-level clothing constraints; callers can append output requirements
        or other context-specific instructions.
        """
        return (
            "You are generating a full-body 2D avatar from a real person photo.\n\n"
            "INPUT:\n"
            "- A full-body or partial-body photo of a real person.\n\n"
            "TASK:\n"
            "Create a complete full-body avatar of the same person as shown in the input image.\n\n"
            "STYLE REQUIREMENTS:\n"
            "- The avatar must have a realistic human texture.\n"
            "- Preserve natural skin texture, realistic shading, and lifelike facial details.\n"
            "- The output should look like a real human rendered in a clean, flat, 2D composition (not 3D, not cartoon).\n"
            "- Avoid stylized filters, painting effects, comic effects, anime style, or exaggerated features.\n\n"
            "IDENTITY PRESERVATION:\n"
            "- Preserve the person’s hairstyle accurately.\n"
            "- Preserve the person’s face shape, key facial features, and approximate expression.\n"
            "- Preserve the person’s body shape and body proportions.\n"
            "- Preserve the person’s approximate skin tone with realistic lighting.\n\n"
            "POSE CORRECTION:\n"
            "- If the original pose is rotated, occluded, or partially missing, correct it to a natural upright front-facing full-body pose.\n"
            "- Complete any missing parts of the body (legs, hands, feet, etc.) while maintaining realistic proportions.\n"
            "- Ensure both feet are visible and placed naturally.\n\n"
            "BACKGROUND:\n"
            "- Remove the background where appropriate.\n"
            "- No shadows, no floor, no environmental elements.\n\n"
            ""
        )

    # Note: output requirements are intentionally omitted — callers should not
    # append an output-requirements block. Gemini is instructed by the shared
    # prompt and CLOTHING section only.


    def _clothing_section(self, descriptions: list[str] | None) -> str:
        """Return the `CLOTHING` section for the prompt.

        If `descriptions` is empty or None, return a default indicating plain clothes.
        """
        if not descriptions:
            return (
                "CLOTHING:\n"
                "- The subject should wear plain, simple clothes suitable for overlays (no logos)."
            )
        return "CLOTHING:\n" + "\n".join(f"- {d}" for d in descriptions)

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

    def try_on(self, user_id: int, clothing_ids: list[int]) -> bytes:
        """Generate an image of the user's avatar trying on the given clothing items.

        - `user_id`: owner id whose avatar to use (avatar is read from MinIO at
          `/avatars/user_{user_id}`).
        - `clothing_ids`: iterable of garment ids to try on; we read each garment
          from the DB and include a short description in the Gemini prompt.

        Returns: raw PNG bytes from Gemini. Raises `AvatarGenerationError` on any
        failure (missing DB session, missing garment, MinIO access, or Gemini
        generation failure).
        """

        descriptions: list[str] = []
        try:
            with session_scope(self._session_factory) as session:
                store = MakeGarmentStore(session)
                for gid in clothing_ids:
                    g = store.get(gid)
                    if g is None:
                        raise AvatarGenerationError(f"garment not found: {gid}")
                    descriptions.append(
                        f"(HEXCODE color={g.color}, category={g.category.name}, material={g.material.name})"
                    )
        except AvatarGenerationError:
            raise
        except Exception as e:
            print(e)
            raise AvatarGenerationError("failed reading garments from DB") from e

        # Read avatar image bytes from MinIO
        key = f"user_{user_id}"
        try:
            obj = self._minio.get_object(self.bucket, key)
            avatar_bytes = obj.read()
            obj.close()
        except Exception as e:
            print(e)
            raise AvatarGenerationError("failed to read avatar from MinIO") from e

        # Reuse the central Gemini call; pass the avatar bytes and the clothing
        # descriptions so the CLOTHING section is injected into the shared prompt.
        return self._call_gemini(avatar_bytes, requested_descriptions=descriptions)

