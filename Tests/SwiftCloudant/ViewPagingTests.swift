//
//  ViewPagingTests.swift
//  SwiftCloudant
//
//  Created by Rhys Short on 02/08/2016.
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
import XCTest
@testable import SwiftCloudant

class ViewPagingTests : XCTestCase {
    
    lazy var dbName: String = { return self.generateDBName()}()
    var client: CouchDBClient? = nil
    
    override func setUp() {
        super.setUp()
        
        dbName = generateDBName()
        client = CouchDBClient(url: URL(string: url)!, username: username, password: password)
        createDatabase(databaseName: dbName, client: client!)
        
        
        let mapFunc = "function (doc) { emit(doc._id, null) }"
        let ddoc = ["views": ["paging": ["map": mapFunc]]]
        
        let createDoc = PutDocumentOperation(id:"_design/paging", body: ddoc, databaseName: dbName) { response, httpInfo, error in
            XCTAssertNil(error)
            XCTAssertNotNil(httpInfo)
            XCTAssertNotNil(response)
            if let httpInfo = httpInfo {
                XCTAssert(httpInfo.statusCode / 100 == 2)
            }
        }
        client?.add(operation: createDoc).waitUntilFinished()
        
        var count:Int = 0
        for doc in createTestDocuments(count: 10) {
            let putDoc = PutDocumentOperation(id: "paging-\(count)", body: doc, databaseName: dbName) { response, httpInfo, error in
                XCTAssertNotNil(response)
                XCTAssertNotNil(httpInfo)
                XCTAssertNil(error)
                
            }
            client?.add(operation: putDoc).waitUntilFinished()
            count += 1
        }
    }
    
    override func tearDown() {
        deleteDatabase(databaseName: dbName, client: client!)
        
        super.tearDown()
        
        print("Deleted database: \(dbName)")
    }
    
    func testPageForward(){
        
        let expectation = self.expectation(description: "Paging views")
        
        var firstPage: [String:AnyObject] = [:]
        var isFirst: Bool = true
        
        let viewPage = ViewPage(name: "paging", designDocumentID: "paging", databaseName: dbName, client: client!, pageSize: 5){ (page: [String : AnyObject]?, token: PageToken?, error: Error?) -> ViewPage.Paging in
            XCTAssertNotNil(page)
            XCTAssertNil(error)
            if let page = page {
                if isFirst {
                    firstPage = page
                } else {
                    XCTAssertNotEqual(firstPage as NSDictionary, page)
                }
                
                let rows = page["rows"] as! [[String :AnyObject]]
                let ids = rows.reduce([]) { (partialResult, row) -> [String] in
                    var partialResult = partialResult
                    partialResult.append(row["id"] as! String)
                    return partialResult
                }
                XCTAssertEqual(rows.count, ids.count)
                XCTAssertEqual(5, ids.count)
                
                var startNumber: Int
                if isFirst {
                    startNumber = 0
                } else {
                    startNumber = 5
                }
                
                for id in ids {
                    let last = id.components(separatedBy: "-").last!
                    XCTAssertEqual(startNumber, Int(last))
                    startNumber += 1
                    
                }
            }
            
            if !isFirst {
                expectation.fulfill()
            }
            
            if isFirst {
                isFirst = false
                return .next
            } else {
                return .stop
            }
            
        }
        
        // Start paging.
        viewPage.makeRequest()
        
        self.waitForExpectations(timeout: 20.0)
        
        
    }
    
    func testPageBackward(){
        
        let expectation = self.expectation(description: "Paging views")
        
        var firstPage: [String:AnyObject] = [:]
        var isFirst: Bool = true
        var isSecond: Bool = false
        
        let viewPage = ViewPage(name: "paging", designDocumentID: "paging", databaseName: dbName, client: client!, pageSize: 5){ (page: [String : AnyObject]?, token: PageToken?, error: Error?) -> ViewPage.Paging in
            XCTAssertNotNil(page)
            XCTAssertNil(error)
            
            if let page = page {
                if isFirst {
                    firstPage = page
                    isFirst = false
                    isSecond = true
                    return .next
                } else if isSecond {
                    XCTAssertNotEqual(firstPage as NSDictionary, page)
                    isSecond = false
                    return .previous
                } else {
                    XCTAssertEqual(firstPage as NSDictionary, page)
                }
                
                let ids = self.extractIDs(from: page)
                XCTAssertEqual(5, ids.count)
                
                var startNumber = 0
                
                for id in ids {
                    let last = id.components(separatedBy: "-").last!
                    XCTAssertEqual(startNumber, Int(last))
                    startNumber += 1
                    
                }
            }
            
            if !isSecond && !isFirst {
                expectation.fulfill()
            }
            
            return .stop
            
        }
        
        // Start paging.
        viewPage.makeRequest()
        
        self.waitForExpectations(timeout: 20.0)
        
        
    }
    
    func extractIDs(from response: [String :AnyObject]) -> [String]{
        
        let rows = response["rows"] as! [[String :AnyObject]]
        return rows.reduce([]) { (partialResult, row) -> [String] in
            var partialResult = partialResult
            partialResult.append(row["id"] as! String)
            return partialResult
        }

    }
    
    
}

