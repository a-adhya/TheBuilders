from dataclasses import dataclass, field
from dataclasses_json import dataclass_json, config
from http import HTTPStatus
import httpx
from typing import Callable, Dict, List, Optional, Awaitable

@dataclass_json
@dataclass
class OllamaParamProp:
    type:        str
    description: str
    enum:        Optional[List[str]] = None

@dataclass_json
@dataclass
class OllamaFunctionParams:
    type:       str
    properties: Dict[str, OllamaParamProp]
    required:   Optional[List[str]] = None

@dataclass_json
@dataclass
class OllamaToolFunction:
    name:        str
    description: str
    parameters:  Optional[OllamaFunctionParams] = None

@dataclass_json
@dataclass
class OllamaToolSchema:
    type: str
    function: OllamaToolFunction

WEATHER_TOOL = OllamaToolSchema(
    type = "function",
    function = OllamaToolFunction(
        name = "get_weather",
        description = "Get current temperature",
        parameters = OllamaFunctionParams(
            type = "object",
            properties = {
                "latitude": OllamaParamProp(
                    type = "string",
                    description = "latitude of location of interest",
                ),
                "longitude": OllamaParamProp(
                    type = "string",
                    description = "longitude of location of interest",
                ),
            },
            required = ["latitude", "longitude"],
        ),
    ),
)

@dataclass_json
@dataclass
class Current:
    temp: float = field(
        default=None,
        metadata=config(field_name="temperature_2m")
    )

@dataclass_json
@dataclass
class OMeteoResponse:
    latitude: float
    longitude: float
    current: Current

async def getWeather(argv: List[str]) -> tuple[Optional[str], Optional[str]]:
    # Open-Meteo API doc: https://open-meteo.com/en/docs#api_documentation
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                url=f"https://api.open-meteo.com/v1/forecast?latitude={argv[0]}&longitude={argv[1]}&current=temperature_2m&temperature_unit=fahrenheit",
            )
            if response.status_code != HTTPStatus.OK:
                return None, f"Open-meteo response: {response.status_code}"

            ometeoResponse = OMeteoResponse.from_json(response.content)
            return f"Weather at lat: {ometeoResponse.latitude}, lon: {ometeoResponse.longitude} is {ometeoResponse.current.temp}ºF", None
    except Exception as err:
        return None, f"Cannot connect to Open Meteo: {err}"

type ToolFunction = Callable[[List[str]], Awaitable[tuple[Optional[str], Optional[str]]]]

@dataclass
class Tool:
    schema: OllamaToolSchema
    function: ToolFunction

TOOLBOX: Dict[str, Tool] = {
    "get_weather": Tool(WEATHER_TOOL, getWeather),
}

@dataclass_json
@dataclass
class OllamaFunctionCall:
    name:      str
    arguments: Dict[str, str]

@dataclass_json
@dataclass
class OllamaToolCall:
    function: OllamaFunctionCall

async def toolInvoke(function: OllamaFunctionCall) -> tuple[Optional[str], Optional[str]]:
    tool = TOOLBOX.get(function.name)
    if tool:
        argv = list(function.arguments.values())
        return await tool.function(argv)
    return None, None

