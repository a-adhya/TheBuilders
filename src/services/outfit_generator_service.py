from anthropic import Anthropic
from dotenv import load_dotenv
import os
from api.schema import GenerateOutfitResponse, ListByOwnerResponse


class OutfitGeneratorService:
    def __init__(self):
        load_dotenv()
        api_key = os.getenv("API_KEY")
        self.client = Anthropic(api_key=api_key)

    def forward_to_frontend(self, tool_use):
        # Placeholder function to forward tool use request to iOS frontend.
        pass

    def call_weather_api(self, input_data):
        # Placeholder function to call a weather API with the given input data
        # and return the weather information.
        pass

    def generate_outfit(
        self, closet: ListByOwnerResponse, context: str
    ) -> GenerateOutfitResponse:
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
            },
            {
                "name": "get_location",
                "description": "Get user's current GPS location from device",
                "input_schema": {
                    "type": "object",
                    "properties": {}
                }
            },
            {
                "name": "get_weather",
                "description": "Get the current weather in a given location",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "lat": {"type": "number", "description": "Latitude"},
                        "lon": {"type": "number", "description": "Longitude"},
                    },
                    "required": ["lat", "lon"]
                }
            }
        ]

        query = f"""
        Given the following list of garments:

        <garments>
        {closet}
        </garments>

        and the following context:

        <context>
        {context}
        </context>

        Recommend an optimal and fashionable outfit by selecting a subset of garments from the list above.
        Use the `get_location` tool and the `get_weather` tool to get the current weather and location if needed.
        This extra weather context will help you make better outfit recommendations.

        When ready, use the `print_outfit_garments` tool to output the list of garment IDs that make up the outfit.
        """

        response = self.client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            tools=tools,
            tool_choice={"type": "any"},
            disable_parallel_tool_use=True,
            messages=[{"role": "user", "content": query}],
        )
        previous_messages = []
        previous_messages.append({"role": "user", "content": query})

        # Agentic loop to handle tool use
        while True:
            # Extract tool use requests
            tool = None
            for content in response.content:
                if content.type == "tool_use":
                    tool = content

            # Execute tool
            if tool.name == "get_location":
                # Forward to iOS frontend, wait for response
                result = self.forward_to_frontend()
            elif tool.name == "get_weather":
                # Execute backend weather API call
                result = self.call_weather_api(tool.input)
            elif tool.name == "print_outfit_garments":
                # Final tool use, break loop
                break

            tool_results = [{
                "type": "tool_result",
                "tool_use_id": response.id,
                "content": result
            }]

            previous_messages = [
                *previous_messages,
                {"role": "assistant", "content": response.content},
                {"role": "user", "content": tool_results}
            ]

            # Continue conversation with tool results
            response = self.client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=1024,
                tools=tools,
                tool_choice={"type": "any"},
                disable_parallel_tool_use=True,
                messages=previous_messages
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
                    garment for garment in closet.garments if garment.id in gid_set
                ]
            )
        else:
            raise Exception("Error: Something went wrong with Claude API")
