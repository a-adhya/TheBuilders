//
//  Toolbox.swift
//  swiftUIChatter
//
//  Created by Karthik Jonnalagadda on 11/5/25.
//

import Foundation

// MARK: - Ollama tool schema (device-side encoding)
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
        case type, description
        case enum_ = "enum"
    }
}

// MARK: - get_location schema
let LOC_TOOL = OllamaToolSchema(
    type: "function",
    function: OllamaToolFunction(
        name: "get_location",
        description: "Get current location",
        parameters: nil
    )
)

// MARK: - Tool registry
typealias ToolFunction = ([String]) async -> String?

struct Tool {
    let schema: OllamaToolSchema
    let function: ToolFunction
    let arguments: [String] // labels in order, if function takes named args
}

// Our only device tool for this tutorial
let TOOLBOX: [String: Tool] = [
    "get_location": Tool(schema: LOC_TOOL, function: { _ in
        let loc = LocManagerViewModel.shared.location
        return "latitude: \(loc.lat), longitude: \(loc.lon)"
    }, arguments: [])
]

// MARK: - Tool call decoding + dispatcher
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
            if let arg = function.arguments[label] { argv.append(arg) }
        }
        return await tool.function(argv)
    }
    return nil
}
