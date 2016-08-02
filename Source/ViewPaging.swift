//
//  ViewPaging.swift
//  SwiftCloudant
//
//  Created by Rhys Short on 01/08/2016.
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



public struct PageToken {
    
    fileprivate let viewQueryParams: [String: Any]
    fileprivate let client: CouchDBClient
    
}

public class ViewPage {
    
    public enum Paging {
        case next
        case previous
        case `repeat`
        case stop
    }
    
    public enum Error : Swift.Error {
        case unsupportedOption // for when the opttion that doesn't make sense in this context is returned.
    }
    
    private struct State {
        var lastEndKey: AnyObject?
        var lastEndKeyDocID: String?
        
        var lastStartKey: AnyObject?
        var lastStartKeyDocID: String?
    }
    
    private let pageHandler: (page: [String : AnyObject]?, token: PageToken?, error: Swift.Error?) -> Paging
    
    private let rowHandler: ((row: [String: AnyObject]) -> Void)?
    
    private let pageSize: UInt
    
    private let client: CouchDBClient
    
    // MARK: User provided parameters for the view Op.
    private let descending: Bool?
    private let startKey: AnyObject?
    private let startKeyDocumentID:String?
    private let endKey: AnyObject?
    private let endKeyDocumentID: String?
    private let inclusiveEnd:Bool?
    private let key:AnyObject?
    private let keys:[AnyObject]?
    private let includeDocs:Bool?
    private let conflicts:Bool?
    private let stale:Stale?
    private let includeLastUpdateSequenceNumber: Bool?
    
    private let name: String
    private let designDocumentID: String
    private let databaseName:String
    
    /// MARK: state properties for generating the next page etc.
    private var state: State = State()
    
    public init(name: String,
                designDocumentID: String,
                databaseName:String,
                client: CouchDBClient,
                pageSize: UInt = 25,
                descending: Bool? = nil,
                startKey: AnyObject? = nil,
                startKeyDocumentID:String? = nil,
                endKey: AnyObject? = nil,
                endKeyDocumentID: String? = nil,
                inclusiveEnd:Bool? = nil,
                key:AnyObject? = nil,
                keys:[AnyObject]? = nil,
                includeDocs:Bool? = nil,
                conflicts:Bool? = nil,
                stale:Stale? = nil,
                includeLastUpdateSequenceNumber: Bool? = nil,
                rowHandler:((row: [String: AnyObject]) -> Void)? = nil,
                pageHandler: (page: [String : AnyObject]?, token: PageToken?, error: Swift.Error?) -> Paging) {
        
        self.name = name
        self.designDocumentID = designDocumentID
        self.databaseName = databaseName
        self.pageSize = pageSize
        self.pageHandler = pageHandler
        self.rowHandler = rowHandler
        self.client = client
        self.descending = descending
        self.startKey = startKey
        self.startKeyDocumentID = startKeyDocumentID
        self.endKey = endKey
        self.endKeyDocumentID = endKeyDocumentID
        self.inclusiveEnd = inclusiveEnd
        self.key = key
        self.keys = keys
        self.includeDocs = includeDocs
        self.conflicts = conflicts
        self.stale = stale
        self.includeLastUpdateSequenceNumber = includeLastUpdateSequenceNumber
    }
    
    public func makeRequest() {
        self.makeRequest(page: nil)
    }
    

    /**
     Makes a query view request.
     
     - parameter page: the page to request or `nil` if it is the first page.
     */
    private func makeRequest(page: Paging?){
        /// This should also make the requests for other pages, so the way to do that will be to
        // have a private method to shadow this one, with the Paging enum. as a param and then
        // it does the right thing depending on what it is.
        
        
        let startKey: AnyObject?
        let startKeyDocumentID: String?
        let endKey: AnyObject?
        let endKeyDocumentID: String?
        let descending: Bool?
        let inclusiveEnd: Bool?
        
        if let page = page {
            switch (page){
            case .next:
                startKey = self.state.lastEndKey
                startKeyDocumentID = self.state.lastEndKeyDocID
                endKey = self.endKey
                endKeyDocumentID = self.endKeyDocumentID
                descending = self.descending
                inclusiveEnd = self.inclusiveEnd
                break
            case .previous:
                startKey = self.state.lastEndKey
                startKeyDocumentID = self.state.lastEndKeyDocID
                endKey = nil
                endKeyDocumentID = nil
                descending = self.descending == nil ? true : !(self.descending!)
                inclusiveEnd = true
                break
            default:
                abort() // aborting for now, when this is finished we should never hit this.
                break
            }
        } else {
            startKey = self.startKey
            startKeyDocumentID = self.startKeyDocumentID
            endKey = self.endKey
            endKeyDocumentID = self.endKeyDocumentID
            descending = self.descending
            inclusiveEnd = self.inclusiveEnd
        }
        
        
        let viewOp = QueryViewOperation(name: name, designDocumentID: designDocumentID, databaseName: databaseName, descending: descending, startKey: startKey, startKeyDocumentID: startKeyDocumentID, endKey: endKey, endKeyDocumentID: endKeyDocumentID, inclusiveEnd: inclusiveEnd, key: key, keys: keys, limit: pageSize + 1, skip: 0, includeDocs: includeDocs, conflicts: conflicts, reduce: false, stale: stale, includeLastUpdateSequenceNumber: includeLastUpdateSequenceNumber, rowHandler: { (row: [String : AnyObject]) -> Void in
            
            // DO Nothing, we would have to track the number of times called, it's easier to call the func
            // during the completionHandler phase.
            
            
            }, completionHandler: { (response, httpInfo, error) in
                
                if let response = response, let rows = response["rows"] as? [[String: AnyObject]] {
                    
                    let filteredRows: [[String: AnyObject]]
                    
                    // we should only filter last if we are going forward, if backwards we need to filter the first.
                    if rows.count > Int(self.pageSize) {
                        
                        let last = rows.last!
                        self.state.lastEndKey = last["key"]
                        self.state.lastEndKeyDocID = last["id"] as? String
                        
                        
                        filteredRows = Array(rows.dropLast())
                        
                        
                    } else {
                        filteredRows = rows
                    }
                    
                    // call the row handler.
                    for row in filteredRows {
                        self.rowHandler?(row: row)
                    }
                    
                    var requestedResponse = response
                    requestedResponse["rows"] = filteredRows
                    
                    // TODO: Generate the token so we can go back around again.
                    let returned = self.pageHandler(page: requestedResponse, token: nil, error: error)
                    
                    switch returned {
                    case .stop:
                    return // requests should stop. just exit the scope
                    case .repeat :
                        // readd the operation, it can be used again.
                        break
                    default :
                        self.makeRequest(page: returned)
                    }
                    
                } else {
                    let continuation =  self.pageHandler(page: nil, token: nil, error: error)
                    
                    switch (continuation) {
                    case .repeat:
                        // remake the request and queue.
                        break
                    default :
                        // we should error out here, in this state only repeat is allowed.
                        break
                        
                    }
                }
        })
        
        client.add(operation: viewOp)
        
    }
    
    public class func nextPage(token: PageToken){
        
    }
    
    public class func previousPage(token: PageToken){
        
    }
    
    public class func nextPage(token: String) {
        
    }
    
    public class func previousPage(token: String) {
        
    }
    
    
    
}




