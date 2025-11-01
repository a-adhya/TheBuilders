from typing import List, Optional
from anthropic import Anthropic
from dotenv import load_dotenv
import os
from db.schema import Garment
from api.schema import GenerateOutfitResponse


class OutfitGeneratorService:
    def __init__(self):
        load_dotenv()
        api_key = os.getenv("API_KEY")
        self.client = Anthropic(api_key=api_key)

    def generate_outfit(self, garments: List[Garment], context: str) -> GenerateOutfitResponse:
        tools = [
            {
                "name": "print_outfit_garments",
                "description": "Prints garments for an optimal and fashionable outfit given a list of garments and context.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "garments": {
                            "type": "array",
                            "items": {
                                "type": "integer",
                                "description": "The ID of a garment available to choose from.",
                            },
                            "description": "List id's of garments chosen in the optimal outfit.",
                        }
                    },
                    "required": ["garments"],
                },
            }
        ]

        query = f"""
        A garment has the following categories:
        SHIRT = 1
        TSHIRT = 2
        JACKET = 3
        SWEATER = 4
        JEANS = 5
        PANTS = 6
        SHORTS = 7
        SHOES = 8
        ACCESSORY = 9

        Given the following list of garments:

        <garments>
        {garments}
        </garments>

        and the following context:

        <context>
        {context}
        </context>

        Recommend an optimal and fashionable outfit by selecting a subset of garments from the list above.

        Use the `print_outfit_garments` tool.
        """

        response = self.client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1000,
            tools=tools,
            tool_choice={"type": "tool", "name": "print_outfit_garments"},
            messages=[{"role": "user", "content": query}],
        )

        outfit_output = None
        for content in response.content:
            if content.type == "tool_use" and content.name == "print_outfit_garments":
                outfit_output = content.input
                break

        if outfit_output:
            garment_ids = outfit_output.get("garments", [])
            gid_set = set(garment_ids)
            return GenerateOutfitResponse(
                garments=[
                    garment for garment in garments if garment.id in gid_set]
            )
        else:
            raise Exception("Error: Something went wrong with Claude API")
