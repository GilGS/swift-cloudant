//
//  BulkDocs.swift
//  SwiftCloudant
//
//  Created by Rhys Short on 27/07/2016.
//
//  Copyright (c) 2016 IBM Corp.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

import Foundation

public class PutBulkDocsOperation : CouchDatabaseOperation, JSONOperation {
    
    public typealias Json = [[String: AnyObject]]

    public let databaseName: String
    
    public let completionHandler: ((response: [[String:AnyObject]]?, httpInfo:HTTPInfo?, error:Error?) -> Void)?
    
    public let documents: [[String:AnyObject]]
    
    public let newEdits: Bool?
    
    public let allOrNothing: Bool?
    
    public init(databaseName: String,
                documents:[[String:AnyObject]],
                newEdits: Bool? = nil,
                allOrNothing: Bool? = nil,
                completionHandler: ((response: [[String:AnyObject]]?, httpInfo:HTTPInfo?, error:Error?) -> Void)? = nil){
        self.databaseName = databaseName
        self.documents = documents
        self.newEdits = newEdits
        self.allOrNothing = allOrNothing
        self.completionHandler = completionHandler
    }
    
    public var endpoint: String {
        return "/\(databaseName)/_bulk_docs"
    }
    
    public func validate() -> Bool {
        return JSONSerialization.isValidJSONObject(documents)
    }
    
    
    private var jsonData: Data?
    
    public func serialise() throws {
        var request:[String:AnyObject] = ["docs":documents]
        
        if let newEdits = newEdits {
            request["new_edits"] = newEdits
        }
        
        if let allOrNothing = allOrNothing {
            request["all_or_nothing"] = allOrNothing
        }
        
        jsonData = try JSONSerialization.data(withJSONObject: request);
    }
    
    public var data: Data? {
        return jsonData
    }
    
    public var method:String {
        return "POST"
    }


}

