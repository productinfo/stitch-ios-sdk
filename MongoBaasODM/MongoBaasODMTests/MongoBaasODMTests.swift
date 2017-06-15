//
//  MongoBaasODMTests.swift
//  MongoBaasODMTests
//
//  Created by Ofer Meroz on 15/03/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import MongoBaasODM
import MongoExtendedJson
import MongoDB

class MongoBaasODMTests: XCTestCase {
    
    override func setUp() {
        super.setUp()        
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testProjectionWithArray() {
        let array = ["name", "age"]
        let projection = Projection(array)
        let projectionDocument = projection.asDocument
        
        XCTAssertEqual(projectionDocument["name"] as? Bool, true)
        XCTAssertEqual(projectionDocument["age"] as? Bool, true)
    }
    
    func testProjectionWithArrayLiteral() {
        let projection = ["name", "age"] as Projection
        let projectionDocument = projection.asDocument

        XCTAssertEqual(projectionDocument["name"] as? Bool, true)
        XCTAssertEqual(projectionDocument["age"] as? Bool, true)
    }

}