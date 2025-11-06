//
//  Toolbox.swift
//  swiftUIChatter
//
//  Created by Karthik Jonnalagadda on 11/5/25.
//

import Foundation

struct OllamaToolSchema: Encodable {
    let type: String
    let function: OllamaToolFunction
}

struct OllamaToolFunction: Encodable {
    let name: String
    let description: String
    let parameters: OllamaFunctionParams?
}

struct OllamaFunctionParams: Encodable {
    let type: String
    let properties: [String:OllamaParamProp]?
    let required: [String]?
}

struct OllamaParamProp: Encodable {
    let type: String
    let description: String
    let enum_: [String]?
    
    enum CodingKeys: String, CodingKey {
        // to map json field to property
        // if specify one, must specify all
        case type = "type"
        case description = "descriptionn"
        case enum_ = "enum"
    }
}

let LOC_TOOL = OllamaToolSchema(
    type: "function",
    function: OllamaToolFunction(
        name: "get_location",
        description: "Get current location",
        parameters: nil
    )
)

func getLocation(_ argv: [String]) async -> String? {
    "latitude: \(LocManagerViewModel.shared.location.lat), longitude: \(LocManagerViewModel.shared.location.lon)"
}

typealias ToolFunction = ([String]) async -> String?

struct Tool {
    let schema: OllamaToolSchema
    let function: ToolFunction
    let arguments: [String]
}

let TOOLBOX = [
    "get_location": Tool(schema: LOC_TOOL, function: getLocation, arguments: []),
]

struct OllamaToolCall: Codable {
    let function: OllamaFunctionCall
}

struct OllamaFunctionCall: Codable {
    let name: String
    let arguments: [String:String]
}

func toolInvoke(function: OllamaFunctionCall) async -> String? {
    if let tool = TOOLBOX[function.name] {
        var argv = [String]()
        for label in tool.arguments {
            // get arguments in order, Dict doesn't preserve insertion order
            if let arg = function.arguments[label] {
                argv.append(arg)
            }
        }
        return await tool.function(argv)
    }
    return nil
}
