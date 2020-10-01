import Foundation

public struct SubscriptionRequest<R: Request> {
    let operationName: String
    let request: R
    let id: String
    
    init(request: R, operationName: String) throws {
        self.operationName = operationName
        self.request = request
        self.id = try SubscriptionRequest.generateRequestId(request: request,
                                                          operationName: operationName)
    }
    
    public func subscriptionMessage() throws -> String? {
        let query = try self.request.queryDocument.graphQLString()
        
        var body: GraphQLMap = [
            "operationName": operationName,
            "query": query
        ]
        
        if let variables = try self.request.variables?.graphQLVariablesDictionary() {
            body["variables"] = variables
        }
        
        guard let message = GraphQLWSProtocol(payload: body, id: self.id).rawMessage else {
            throw WebSocketError.messagePayloadFailed(body)
        }

        return message
    }
    
    static func generateRequestId<R: Request>(request: R, operationName: String) throws -> String {
        let start = "\(operationName):{"
        let id = try request.variables?.graphQLVariablesDictionary().reduce(into: start, { (result, arg1) in
            guard let value = arg1.value as? String, let key = arg1.key as? String else {
                return
            }
            
            result += "\(key) : \(value),"
        }) ?? operationName
        
        return id + "}"
    }
}

public struct GraphQLWSProtocol {
    public enum Types : String {
        case connectionInit = "connection_init"            // Client -> Server
        case connectionTerminate = "connection_terminate"  // Client -> Server
        case start = "start"                               // Client -> Server
        case stop = "stop"                                 // Client -> Server
        
        case connectionAck = "connection_ack"              // Server -> Client
        case connectionError = "connection_error"          // Server -> Client
        case connectionKeepAlive = "ka"                    // Server -> Client
        case data = "data"                                 // Server -> Client
        case error = "error"                               // Server -> Client
        case complete = "complete"                         // Server -> Client
    }
    
    enum Key: String {
        case id
        case type
        case payload
    }
    
    var message: GraphQLMap = [:]
    var serialized: String?
    
    var rawMessage: String? {
        guard let serialized = try? JSONSerialization.data(withJSONObject: self.message, options: .fragmentsAllowed) else {
            return nil
        }
        
        return String(data: serialized, encoding: .utf8)
    }
    
    init(payload: GraphQLMap? = nil,
         id: String? = nil,
         type: Types = .start) {
        if let payload = payload {
            self.message[Key.payload.rawValue] = payload
        }
        
        if let id = id  {
            self.message[Key.id.rawValue] = id
        }
        
        self.message[Key.type.rawValue] = type.rawValue
    }
}
