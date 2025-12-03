from dotenv import load_dotenv
from anthropic import Anthropic
import os
import httpx
from api.schema import GenerateOutfitResponse, ListByOwnerResponse
from typing import Optional, List, Dict, Any


class OutfitGeneratorService:
    def __init__(self, client: Optional[object] = None):
        """Create the service.

        If `client` is provided, use it (useful for tests). Otherwise try to
        construct a real Anthropic client. If Anthropic isn't installed or
        cannot be created, set `self.client = None` — callers/tests should
        inject a client before calling methods that use it.
        """
        if client is not None:
            self.client = client
            return

        # Lazily attempt to create the real Anthropic client. Keep this
        # in a try/except so tests (which don't have the package) don't
        # fail during import.
        try:
            load_dotenv()
            api_key = os.getenv("API_KEY")
            self.client = Anthropic(api_key=api_key)
        except Exception:
            # No real client available (e.g., in test environments).
            self.client = None

    def call_weather_api(self, latitude, longitude):
        """
        Fetch current weather data using Open-Meteo API (free, no API key required).
        Returns a formatted string with weather information for Claude to use.
        """
        try:
            url = (
                f"https://api.open-meteo.com/v1/forecast"
                f"?latitude={latitude}&longitude={longitude}"
                f"&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code"
                f"&daily=temperature_2m_max,temperature_2m_min"
                f"&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto"
            )
            
            response = httpx.get(url, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            
            current = data.get("current", {})
            daily = data.get("daily", {})
            
            temp_f = round(current.get("temperature_2m", 0))
            humidity = round(current.get("relative_humidity_2m", 0))
            wind_mph = round(current.get("wind_speed_10m", 0))
            weather_code = current.get("weather_code", 0)
            
            daily_max = daily.get("temperature_2m_max", [])
            daily_min = daily.get("temperature_2m_min", [])
            high_f = round(daily_max[0]) if daily_max else temp_f
            low_f = round(daily_min[0]) if daily_min else temp_f
            
            # Map weather code to condition (WMO Weather interpretation codes)
            condition = self._get_weather_condition(weather_code)
            
            weather_info = (
                f"Current weather at location ({latitude}, {longitude}): "
                f"Temperature: {temp_f}°F (High: {high_f}°F, Low: {low_f}°F), "
                f"Condition: {condition}, "
                f"Humidity: {humidity}%, "
                f"Wind Speed: {wind_mph} mph"
            )
            
            return weather_info
            
        except Exception as e:
            return (
                f"Weather information for location ({latitude}, {longitude}): "
                f"(weather API unavailable: {str(e)})"
            )
    
    def _get_weather_condition(self, weather_code: int) -> str:
        """
        Map WMO Weather interpretation codes to readable conditions.
        Reference: https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM
        """
        if weather_code == 0:
            return "Clear sky"
        elif weather_code in [1, 2, 3]:
            return "Partly cloudy"
        elif weather_code in [45, 48]:
            return "Foggy"
        elif weather_code in [51, 53, 55]:
            return "Drizzle"
        elif weather_code in [61, 63, 65]:
            return "Rain"
        elif weather_code in [71, 73, 75]:
            return "Snow"
        elif weather_code in [80, 81, 82]:
            return "Rain showers"
        elif weather_code in [85, 86]:
            return "Snow showers"
        elif weather_code in [95, 96, 99]:
            return "Thunderstorm"
        else:
            return "Unknown"

    def generate_outfit(
        self,
        closet: ListByOwnerResponse,
        context: str,
        previous_messages: Optional[List[Dict[str, Any]]] = None,
    ) -> GenerateOutfitResponse:
        tools = [
            {
                "name": "print_outfit_garments",
                "description": "Prints garments for an optimal and fashionable outfit given a list of garments and context.",
                "input_schema": {
                    "type": "object",
                    "additionalProperties": False,
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
                    "additionalProperties": False,
                    "properties": {
                        "lat": {"type": "number", "description": "Latitude of given location"},
                        "lon": {"type": "number", "description": "Longitude of given location"},
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

        # initialize previous_messages only when not provided by caller
        if previous_messages is None:
            previous_messages = [{"role": "user", "content": query}]

        response = self.client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            tools=tools,
            tool_choice={"type": "any"},
            messages=previous_messages,
        )

        # Agentic loop to handle tool use
        while True:
            # Check if response was truncated during tool use
            if response.stop_reason == "max_tokens":
                # Send the request with higher max_tokens
                response = self.client.messages.create(
                    model="claude-haiku-4-5-20251001",
                    max_tokens=4096,
                    tools=tools,
                    tool_choice={"type": "any"},
                    messages=previous_messages,
                )
                continue

            # Check if the response has pause_turn stop reason
            if response.stop_reason == "pause_turn":
                previous_messages = [
                    *previous_messages,
                    {"role": "assistant", "content": [
                        block.model_dump() for block in response.content]},
                ]
                # Continue the conversation with the paused content
                response = self.client.messages.create(
                    model="claude-haiku-4-5-20251001",
                    max_tokens=1024,
                    tools=tools,
                    tool_choice={"type": "any"},
                    messages=previous_messages,
                )
                continue

            # Extract tool use requests
            tool = None
            for content in response.content:
                if content.type == "tool_use":
                    tool = content
                    break

            # If no tool use found, check if we have a final response
            if tool is None:
                break

            # Execute tool
            if tool.name == "get_location":
                # Forward to iOS frontend; include conversation state so the
                # frontend can update it and return tool results back to the API.
                tool_results = [{
                    "type": "tool_result",
                    "tool_use_id": tool.id,
                    "content": "No location provided."
                }]
                return GenerateOutfitResponse(
                    response_type="tool_request",
                    previous_messages=[
                        *previous_messages,
                        {"role": "assistant", "content": [
                            block.model_dump() for block in response.content]},
                        {"role": "user", "content": tool_results},
                    ]
                )
            elif tool.name == "get_weather":
                lat = tool.input.get("lat")
                lon = tool.input.get("lon")
                # Execute backend weather API call
                result = self.call_weather_api(lat, lon)
            elif tool.name == "print_outfit_garments":
                # Final tool use, break loop
                break

            tool_results = [{
                "type": "tool_result",
                "tool_use_id": tool.id,
                "content": result
            }]

            previous_messages = [
                *previous_messages,
                {"role": "assistant", "content": [
                    block.model_dump() for block in response.content]},
                {"role": "user", "content": tool_results}
            ]

            # Continue conversation with tool results
            response = self.client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=1024,
                tools=tools,
                tool_choice={"type": "any"},
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
                response_type="garments",
                garments=[
                    garment for garment in closet.garments if garment.id in gid_set
                ],
            )
        else:
            raise Exception("Error: Something went wrong with Claude API")
