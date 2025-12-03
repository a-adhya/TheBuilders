//
//  OutfitGenerationHelper.swift
//  TheBuilders
//
//  Helper functions for handling agentic outfit generation with tool requests
//

import Foundation

func updateLocationToolResult(previousMessages: [[String: Any]], latitude: Double, longitude: Double) -> [[String: Any]] {
    var updatedMessages = previousMessages
    var toolUseId: String? = nil
    
    if let lastAssistant = updatedMessages.last(where: { 
        ($0["role"] as? String) == "assistant" 
    }),
       let content = lastAssistant["content"] as? [[String: Any]] {
        for block in content {
            if block["type"] as? String == "tool_use",
               block["name"] as? String == "get_location",
               let id = block["id"] as? String {
                toolUseId = id
                break
            }
        }
    }
    
    if let lastUserIndex = updatedMessages.indices.last(where: { 
        (updatedMessages[$0]["role"] as? String) == "user" 
    }) {
        var lastUserMessage = updatedMessages[lastUserIndex]
        
        if var content = lastUserMessage["content"] as? [[String: Any]] {
            for (index, block) in content.enumerated() {
                if block["type"] as? String == "tool_result" {
                    if let toolId = toolUseId {
                        if let blockToolUseId = block["tool_use_id"] as? String,
                           blockToolUseId != toolId {
                            continue
                        }
                    }
                    
                    var updatedBlock = block
                    // Format location as JSON string for Anthropic API
                    let locationJSON = """
                    {"lat": \(latitude), "lon": \(longitude)}
                    """
                    updatedBlock["content"] = locationJSON
                    content[index] = updatedBlock
                    break
                }
            }
            
            lastUserMessage["content"] = content
            updatedMessages[lastUserIndex] = lastUserMessage
        }
    }
    
    return updatedMessages
}

func findToolUseId(previousMessages: [[String: Any]], toolName: String) -> String? {
    if let lastAssistant = previousMessages.last(where: { 
        ($0["role"] as? String) == "assistant" 
    }),
       let content = lastAssistant["content"] as? [[String: Any]] {
        for block in content {
            if block["type"] as? String == "tool_use",
               block["name"] as? String == toolName,
               let id = block["id"] as? String {
                return id
            }
        }
    }
    return nil
}

