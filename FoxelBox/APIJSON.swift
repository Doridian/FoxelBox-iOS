//
//  BaseResponse.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import JSONJoy

struct BaseResponse: JSONJoy {
    static let STATUS_INVALID = 598
    static let STATUS_MANUAL = 599
    
    let success: Bool
    let message: String?
    let result: JSONDecoder?
    let statusCode: Int
    
    init(message: String?, statusCode: Int=BaseResponse.STATUS_MANUAL, success: Bool=false) {
        self.success = success
        self.message = message
        self.result = nil
        self.statusCode = statusCode
    }
    
    init(_ decoder: JSONDecoder) throws {
        self.success = decoder["success"].bool
        
        if !self.success {
            self.message = try decoder["message"].getString()
            self.result = nil
        } else {
            self.message = nil
            self.result = decoder["result"]
        }
        
        if let statusCode = decoder["statusCode"].integer {
            self.statusCode = statusCode
        } else if self.success {
            self.statusCode = 200
        } else {
            self.statusCode = BaseResponse.STATUS_INVALID
        }
    }
}

typealias JSONUUID = String

struct LoginResponse: JSONJoy {
    let sessionId: String
    let expiresAt: Int
    
    init(_ decoder: JSONDecoder) throws {
        self.sessionId = try decoder["sessionId"].getString()
        self.expiresAt = try decoder["expiresAt"].getInt()
    }
}

struct UserInfo: JSONJoy {
    let uuid: JSONUUID
    let name: String
    
    init(_ decoder: JSONDecoder) throws {
        self.uuid = try decoder["uuid"].getString()
        self.name = try decoder["name"].getString()
    }
}

struct MessageTarget: JSONJoy {
    let type: String
    let filter: [String]
    
    init(_ decoder: JSONDecoder) throws {
        self.type = try decoder["type"].getString()
        
        var filters = [String]()
        if let filterArray = decoder["filter"].array {
            for filter in filterArray {
                filters.append(try filter.getString())
            }
        } else {
            throw JSONError.wrongType
        }
        self.filter = filters
    }
}

struct ChatMessageOut: JSONJoy {
    let server: String?
    let from: UserInfo?
    let to: MessageTarget
    
    let timestamp: Int
    let id: Int
    
    let context: JSONUUID
    let finalizeContext: Bool
    
    let importance: Int?
    
    let type: String
    let contents: String?
    
    init(_ decoder: JSONDecoder) throws {
        self.server = decoder["server"].string
        
        if decoder["from"].rawValue != nil {
            self.from = try UserInfo(decoder["from"])
        } else {
            self.from = nil
        }
        
        self.to = try MessageTarget(decoder["to"])
        
        self.timestamp = try decoder["timestamp"].getInt()
        self.id = try decoder["id"].getInt()
        
        self.context = try decoder["context"].getString()
        
        self.finalizeContext = decoder["finalizeContext"].bool
        
        self.importance = decoder["importance"].integer
        
        self.type = try decoder["type"].getString()
        self.contents = decoder["contents"].string
        
        if self.type == "text" && self.contents == nil {
            throw JSONError.wrongType
        }
    }
}

struct MessageReply: JSONJoy {
    let latestId: Int
    let messages: [ChatMessageOut]
    
    init(_ decoder: JSONDecoder) throws {
        self.latestId = try decoder["latestId"].getInt()
        
        var messages = [ChatMessageOut]()
        if let messageArray = decoder["messages"].array {
            for message in messageArray {
                messages.append(try ChatMessageOut(message))
            }
        } else {
            throw JSONError.wrongType
        }
        self.messages = messages
    }
}

struct SentMessageReply: JSONJoy {
    let context: JSONUUID
    
    init(_ decoder: JSONDecoder) throws {
        self.context = try decoder["context"].getString()
    }
}
