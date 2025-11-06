import Observation
import SwiftUI

struct OllamaError: Decodable {
    let error: String
}

struct OllamaReply: Decodable {
    let model: String
    let created_at: String
    let response: String
}

enum SseEventType { case Error, Message, ToolCalls }

struct OllamaMessage: Codable {
    let role: String
    let content: String?
    let toolCalls: [OllamaToolCall]?
    
    enum CodingKeys: String, CodingKey {
        // to map json field to property
        // if one is specified, must specify all
        case role = "role"
        case content = "content"
        case toolCalls = "tool_calls"
    }
}

struct OllamaRequest: Encodable {
    let appID: String?
    let model: String?
    var messages: [OllamaMessage]
    let stream: Bool
    var tools: [OllamaToolSchema]?
}

struct OllamaResponse: Decodable {
    let model: String
    let created_at: String
    let message: OllamaMessage
    
    enum CodingKeys: String, CodingKey {
        // to ignore other keys
        case model, created_at, message
    }
}

@Observable
final class ChattStore {
    static let shared = ChattStore() // create one instance of the class to be shared, and
    private init() {} // make the constructor private so no other instances can be created

    private(set) var chatts = [Chatt]()

    private let serverUrl = "https://98.94.19.190"
    
    func llmPrompt(_ chatt: Chatt, errMsg: Binding<String>) async {
        
        self.chatts.append(chatt)

        let jsonObj: [String: Any] = [
            "model": chatt.username as Any,
            "prompt": chatt.message as Any,
            "stream": true
        ]
        guard let requestBody = try? JSONSerialization.data(withJSONObject: jsonObj) else {
            errMsg.wrappedValue = "llmPrompt: JSONSerialization error"
            return
        }

        guard let apiUrl = URL(string: "\(serverUrl)/llmprompt") else {
            errMsg.wrappedValue = "llmPrompt: Bad URL"
            return
        }
        var request = URLRequest(url: apiUrl)
        request.timeoutInterval = 1200 // for 20 minutes
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/*", forHTTPHeaderField: "Accept")
        request.httpBody = requestBody

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                for try await line in bytes.lines {
                    guard let data = line.data(using: .utf8) else {
                        continue
                    }
                    errMsg.wrappedValue = parseErr(code: "\(http.statusCode)", apiUrl: apiUrl, data: data)
                }
                if errMsg.wrappedValue.isEmpty {
                    errMsg.wrappedValue = "\(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))\n\(apiUrl)"
                }
                return
            }

            var resChatt = Chatt(
                username: "assistant (\(chatt.username ?? "ollama"))",
                message: "",
                timestamp: Date().ISO8601Format())
            self.chatts.append(resChatt)
            guard let last = chatts.indices.last else {
                errMsg.wrappedValue = "llmPrompt: chatts array malformed"
                return
            }

            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8) else {
                    continue
                }
                do {
                    let ollamaResponse = try JSONDecoder().decode(OllamaReply.self, from: data)
                    resChatt.message?.append(ollamaResponse.response)
                } catch {
                    errMsg.wrappedValue += parseErr(code: "\(error)", apiUrl: apiUrl, data: data)
                    resChatt.message?.append("\nllmPrompt Error: \(errMsg.wrappedValue)\n\n")
                }
                self.chatts[last] = resChatt  // otherwise changes not observed!
            }
        } catch {
            errMsg.wrappedValue = "llmPrompt: failed \(error)"
        }
    }
    private func parseErr(code: String, apiUrl: URL, data: Data) -> String {
        do {
            let errJson = try JSONDecoder().decode(OllamaError.self, from: data)
            return errJson.error
        } catch {
            return "\(code)\n\(apiUrl)\n\(String(data: data, encoding: .utf8) ?? "error decoding failed")"
        }
    }
    
    func llmTools(appID: String, chatt: Chatt, errMsg: Binding<String>) async {
            self.chatts.append(chatt)
            var resChatt = Chatt(
                username: "assistant (\(chatt.username ?? "ollama"))",
                message: "",
                timestamp: Date().ISO8601Format())
            self.chatts.append(resChatt)
            guard let last = chatts.indices.last else {
                errMsg.wrappedValue = "llmTools: chatts array malformed"
                return
            }

            guard let apiUrl = URL(string: "\(serverUrl)/llmtools") else {
                errMsg.wrappedValue = "llmTools: Bad URL"
                return
            }
            var request = URLRequest(url: apiUrl)
            request.timeoutInterval = 1200 // for 20 minutes
            request.httpMethod = "POST"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-streaming", forHTTPHeaderField: "Accept")

            var ollamaRequest = OllamaRequest(
                appID: appID,
                model: chatt.username,
                messages: [OllamaMessage(role: "user", content: chatt.message, toolCalls: nil)],
                stream: true,
                tools: TOOLBOX.isEmpty ? nil : []
            )

            // append all of on-device tools to ollamaRequest
            for (_, tool) in TOOLBOX {
                ollamaRequest.tools?.append(tool.schema)
            }

        var sendNewPrompt = true
        while sendNewPrompt {
            sendNewPrompt = false
                        
            guard let requestBody = try? JSONEncoder().encode(ollamaRequest) else {
                errMsg.wrappedValue = "llmTools: JSONEncoder error"
                return
            }
            request.httpBody = requestBody
            
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8) else {
                            continue
                        }
                        errMsg.wrappedValue = parseErr(code: "\(http.statusCode)", apiUrl: apiUrl, data: data)
                    }
                    if errMsg.wrappedValue.isEmpty {
                        errMsg.wrappedValue = "\(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))\n\(apiUrl)"
                    }
                    return
                }

                var sseEvent = SseEventType.Message
                var line = ""
                for try await char in bytes.characters {
                    if char != "\n" && char != "\r\n" { // Python eol is "\r\n"
                        line.append(char)
                        continue
                    }
                    if line.isEmpty {
                        // new SSE event, default to Message
                        // SSE events are delimited by "\n\n"
                        if (sseEvent == .Error) {
                            resChatt.message?.append("\n\n**llmTools Error**: \(errMsg.wrappedValue)\n\n")
                            chatts[last] = resChatt  // otherwise changes not observed!
                        }
                        // assuming .ToolCall event handled inline
                        sseEvent = .Message
                        continue
                    }
                    
                    // If the next line starts with `event`, we're starting a new event block
                    let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    let event = parts[1].trimmingCharacters(in: .whitespaces)
                    if parts[0].starts(with: "event") {

                        let event = parts[1].trimmingCharacters(in: .whitespaces)
                        switch event {
                        case "error":
                            sseEvent = .Error
                        case "tool_calls":
                            // new tool calls event!
                            sseEvent = .ToolCalls
                        default:
                            if !event.isEmpty && event != "message" {
                                // we only support "error" and "tool_calls" events,
                                // "message" events are, by the SSE spec,
                                // assumed implicit by default
                                print("LLMTOOLS: Unknown event: '\(parts[1])'")
                            }
                        }

                    } else if parts[0].starts(with: "data") {
                        // not an event line, we only support data line;
                        // multiple data lines can belong to the same event
                        let data = Data(event.utf8)
                        do {
                            let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
                                                        
                            if let token = ollamaResponse.message.content, !token.isEmpty {
                                if sseEvent == .Error {
                                    errMsg.wrappedValue += token
                                } else {
                                    resChatt.message?.append(token)
                                    chatts[last] = resChatt  // otherwise changes not observed!
                                }
                            }
                            
                            if sseEvent == .ToolCalls, let toolCalls = ollamaResponse.message.toolCalls {
                                // message.content is usually empty
                                for toolCall in toolCalls {
                                    let toolResult = await toolInvoke(function: toolCall.function)
                                    
                                    if toolResult != nil {
                                        // create new OllamaMessage with tool result
                                        // to be sent back to Ollama
                                        ollamaRequest.messages = [OllamaMessage(role: "tool", content: toolResult, toolCalls: nil)]
                                        ollamaRequest.tools = nil

                                        // send result back to Ollama
                                        sendNewPrompt = true
                                    } else {
                                        // tool unknown, report to user as error
                                        errMsg.wrappedValue += "llmTools ERROR: tool '\(toolCall.function.name)' called"
                                        resChatt.message?.append("\n\n**llmTools Error**: tool '\(toolCall.function.name)' called\n\n")
                                        chatts[last] = resChatt  // otherwise changes not observed!
                                    }
                                }
                            }

                        } catch {
                            errMsg.wrappedValue += parseErr(code: "\(error)", apiUrl: apiUrl, data: data)
                        }
                    }
                    line = ""
                } // for char in bytes.char

            } catch {
                errMsg.wrappedValue = "llmTools: failed \(error)"
            }
        } // while sendNewPrompt

        }

}

