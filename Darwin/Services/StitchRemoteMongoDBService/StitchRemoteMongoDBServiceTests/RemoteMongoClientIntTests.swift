// swiftlint:disable cyclomatic_complexity
// swiftlint:disable file_length
// swiftlint:disable force_cast
// swiftlint:disable force_try
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

class XCMongoMobileConfiguration: NSObject, XCTestObservation {
    // This init is called first thing as the test bundle starts up and before any test
    // initialization happens
    override init() {
        super.init()
        // We don't need to do any real work, other than register for callbacks
        // when the test suite progresses.
        // XCTestObservation keeps a strong reference to observers
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        try? CoreLocalMongoDBService.shared.initialize()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        CoreLocalMongoDBService.shared.close()
    }
}

class RemoteMongoClientIntTests: BaseStitchIntTestCocoaTouch {

    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = "dbName"
    private let collName = "collName"

    private var mongoClient: RemoteMongoClient!

    override func setUp() {
        super.setUp()

        try! prepareService()
        let joiner = CallbackJoiner()
        getTestColl().deleteMany([:], joiner.capture())
        _ = joiner.capturedValue
    }

    override func tearDown() {
        let joiner = CallbackJoiner()
        getTestColl().deleteMany([:], joiner.capture())
        XCTAssertNotNil(joiner.capturedValue)
        getTestColl().sync.proxy.dataSynchronizer.stop()
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
    }

    private func prepareService() throws {
        let app = try self.createApp()
        _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "mongodb",
            withName: "mongodb1",
            withConfig: ServiceConfigs.mongodb(
                name: "mongodb1", uri: mongodbUri
            )
        )

        _ = try self.addRule(
            toService: svc.1,
            withConfig: RuleCreator.mongoDb(
                database: dbName,
                collection: collName,
                roles: [RuleCreator.Role(
                    read: true, write: true
                )],
                schema: RuleCreator.Schema(properties: Document()))
        )

        let client = try self.appClient(forApp: app.0)

        let exp = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _  in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        self.mongoClient = try client.serviceClient(fromFactory: remoteMongoClientFactory,
                                                    withName: "mongodb1")
    }

    private func getTestColl() -> RemoteMongoCollection<Document> {
        let db = mongoClient.db(dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(collName)
        XCTAssertEqual(dbName, coll.databaseName)
        XCTAssertEqual(collName, coll.name)
        return coll
    }

    private func getTestColl<T>(_ type: T.Type) -> RemoteMongoCollection<T> {
        let db = mongoClient.db(dbName.description)
        XCTAssertEqual(dbName, db.name)
        let coll = db.collection(collName, withCollectionType: type)
        XCTAssertEqual(dbName, coll.databaseName)
        XCTAssertEqual(collName, coll.name)
        return coll
    }

    func testCount() {
        let coll = getTestColl()

        var exp = expectation(description: "should count empty collection")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let rawDoc: Document = ["hello": "world"]
        let doc1 = rawDoc
        let doc2 = rawDoc

        exp = expectation(description: "document should be inserted")
        coll.insertOne(doc1) { (_) in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should count collection with one document")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should be inserted")
        coll.insertOne(doc2) { (_) in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should count collection with two document")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(2, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find two documents with original document as filter")
        coll.count(rawDoc) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(2, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should not find any documents when filtering for nonexistent document")
        coll.count(["hello": "Friend"]) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find one document when limiting result")
        coll.count(rawDoc, options: RemoteCountOptions.init(limit: 1)) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.count(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    private func withoutId(_ document: Document) -> Document {
        var newDoc = Document()
        document.filter { $0.0 != "_id" }.forEach { (key, value) in
            newDoc[key] = value
        }
        return newDoc
    }

    private func withoutIds(_ documents: [Document]) -> [Document] {
        var list: [Document] = []
        documents.forEach { (doc) in
            list.append(withoutId(doc))
        }
        return list
    }

    func testFind() {
        let coll = getTestColl()
        var exp = expectation(description: "should not find any documents in empty collection")
        coll.find().toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual([], docs)
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend", "proj": "field"]

        exp = expectation(description: "should insert two documents")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the inserted documents")
        coll.find().toArray { result in
            switch result {
            case .success(let resultDocs):
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(resultDocs[0]))
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(resultDocs[1]))
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the second document when applying it as a filter")
        coll.find(doc2).first { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(document!))
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should project the result when a projection is specified")
        coll.find(doc2, options: RemoteFindOptions.init(projection: ["proj": 1])).first { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(["proj": "field"], document!)
            case .failure:
                XCTFail("unexpected failure in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "async iterator should work")
        var cursor: RemoteMongoCursor<Document>!

        coll.find().iterator { result in
            switch result {
            case .success(let foundCursor):
                cursor = foundCursor
            case .failure:
                XCTFail("unexpected failure in find")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "iterator should find first document")
        cursor.next({ result in
            switch result {
            case .success(let document):
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(document!))
            case .failure:
                XCTFail("unexpected failure in cursor next")
            }

            exp.fulfill()
        })
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "iterator should find second document")
        cursor.next({ result in
            switch result {
            case .success(let document):
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(document!))
            case .failure:
                XCTFail("unexpected failure in cursor next")
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "iterator should find no more documents")
        cursor.next({ result in
            switch result {
            case .success(let document):
                XCTAssertNil(document)
            case .failure:
                XCTFail("unexpected failure in cursor next")
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.find(["$who": 1]).first { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testAggregate() {
        let coll = getTestColl()
        var exp = expectation(description: "should not find any documents in empty collection")
        coll.aggregate([]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual([], docs)
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend"]

        exp = expectation(description: "should insert two documents")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find the inserted documents")
        coll.aggregate([]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(docs[0]))
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(docs[1]))
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(
            description: "should find the second document when sorting by descending object id, and limiting to 1"
        )
        coll.aggregate([["$sort": ["_id": -1] as Document], ["$limit": 1]]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual(1, docs.count)
                XCTAssertEqual(self.withoutId(doc2), self.withoutId(docs.first!))
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should find first document when matching for it")
        coll.aggregate([["$match": doc1]]).toArray { result in
            switch result {
            case .success(let docs):
                XCTAssertEqual(1, docs.count)
                XCTAssertEqual(self.withoutId(doc1), self.withoutId(docs.first!))
            case .failure:
                XCTFail("unexpected error in aggregate")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid pipeline")
        coll.aggregate([["$who": 1]]).first { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testInsertOne() {
        let coll = getTestColl()
        let doc: Document = ["_id": ObjectId(), "hello": "world"]

        var exp = expectation(description: "document should be successfully inserted")
        coll.insertOne(doc) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(doc["_id"] as! ObjectId, insertResult.insertedId as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should not be inserted again because it would be a duplicate")
        coll.insertOne(doc) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(let message, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                    XCTAssertNotNil(message.range(of: "duplicate"))
                default:
                    XCTFail("unexpected error code")
                }
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should be successfully inserted with a differento object ID")
        coll.insertOne(["hello": "world"]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertNotEqual(doc["_id"] as! ObjectId, insertResult.insertedId as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testInsertMany() {
        let coll = getTestColl()
        let doc1: Document = ["_id": ObjectId(), "hello": "world"]

        var exp = expectation(description: "single document should be successfully inserted")
        coll.insertMany([doc1]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(doc1["_id"] as! ObjectId, insertResult.insertedIds[0] as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "document should not be inserted again because it would be a duplicate")
        coll.insertMany([doc1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(let message, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                    XCTAssertNotNil(message.range(of: "duplicate"))
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc2: Document = ["hello": "world"]
        exp = expectation(description: "document should be successfully inserted with a different object ID")
        coll.insertMany([doc2]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertNotEqual(doc1["_id"] as! ObjectId, insertResult.insertedIds[0] as! ObjectId)
            case .failure:
                XCTFail("unexpected error in insert")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc3: Document = ["one": "two"]
        let doc4: Document = ["three": 4]

        exp = expectation(description: "multiple documents should be successfully inserted")
        coll.insertMany([doc3, doc4]) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(2, insertResult.insertedIds.count)
            case .failure:
                XCTFail("unexpected error in insert")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "all inserted documents should be findable")
        coll.find().toArray { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual(self.withoutIds([doc1, doc2, doc3, doc4]), self.withoutIds(documents))
            case .failure:
                XCTFail("unexpected error in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testDeleteOne() {
        let coll = getTestColl()

        var exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteOne(["hello": "world"]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend"]

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting in a non-empty collection should work")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting in a non-empty collection should work")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "no more items in collection should result in no deletes")
        coll.deleteOne([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting an item by filter work")
        coll.deleteOne(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(
            description: "once the item is deleted, the delete with the filter should no longer delete anything"
        )
        coll.deleteOne(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be one document left in the collection")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be no documents left matching the filter")
        coll.count(doc1) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.deleteOne(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testDeleteMany() {
        let coll = getTestColl()

        var exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteMany([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "delete on an empty collection should result in no deletions")
        coll.deleteMany(["hello": "world"]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let doc1: Document = ["hello": "world"]
        let doc2: Document = ["hello": "friend"]

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting in a non-empty collection should work")
        coll.deleteMany([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(2, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "no more items in collection should result in no deletes")
        coll.deleteMany([:]) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "multiple documents should be inserted")
        coll.insertMany([doc1, doc2]) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "deleting an item by filter work")
        coll.deleteMany(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(1, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(
            description: "once the item is deleted, the delete with the filter should no longer delete anything"
        )
        coll.deleteMany(doc1) { result in
            switch result {
            case .success(let deleteResult):
                XCTAssertEqual(0, deleteResult.deletedCount)
            case .failure:
                XCTFail("unexpected error in delete")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be one document left in the collection")
        coll.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(1, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "there should be no documents left matching the filter")
        coll.count(doc1) { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(0, count)
            case .failure:
                XCTFail("unexpected error in count")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.deleteMany(["$who": 1]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testUpdateOne() {
        let coll = getTestColl()
        let doc1: Document = ["hello": "world"]

        var exp = expectation(description: "updating a document in an empty collection should result in no update")
        coll.updateOne(filter: [:], update: doc1) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "upsert should be successful")
        coll.updateOne(filter: [:], update: doc1, options: RemoteUpdateOptions.init(upsert: true)) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNotNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "updating an existing document should work")
        coll.updateOne(filter: [:], update: ["$set": ["woof": "meow"] as Document]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(1, updateResult.matchedCount)
                XCTAssertEqual(1, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let expectedDoc: Document = ["hello": "world", "woof": "meow"]

        exp = expectation(description: "should find the updated document in the collection")
        coll.find().first { result in
            switch result {
            case .success(let document):
                XCTAssertEqual(expectedDoc, self.withoutId(document!))
            case .failure:
                XCTFail("unexpected error in find")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.updateOne(filter: ["$who": 1], update: [:]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testUpdateMany() {
        let coll = getTestColl()
        let doc1: Document = ["hello": "world"]

        var exp = expectation(description: "updating a document in an empty collection should result in no updates")
        coll.updateMany(filter: [:], update: doc1) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "upsert should be successful")
        coll.updateMany(filter: [:], update: doc1, options: RemoteUpdateOptions.init(upsert: true)) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(0, updateResult.matchedCount)
                XCTAssertEqual(0, updateResult.modifiedCount)
                XCTAssertNotNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "updating an existing document should work")
        coll.updateMany(filter: [:], update: ["$set": ["woof": "meow"] as Document]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(1, updateResult.matchedCount)
                XCTAssertEqual(1, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should insert a document")
        coll.insertOne([:]) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "updating multiple existing documents should work")
        coll.updateMany(filter: [:], update: ["$set": ["woof": "meow"] as Document]) { result in
            switch result {
            case .success(let updateResult):
                XCTAssertEqual(2, updateResult.matchedCount)
                XCTAssertEqual(2, updateResult.modifiedCount)
                XCTAssertNil(updateResult.upsertedId)
            case .failure:
                XCTFail("unexpected error in update")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        let expectedDoc1: Document = ["hello": "world", "woof": "meow"]
        let expectedDoc2: Document = ["woof": "meow"]

        exp = expectation(description: "should find the updated documents in the collection")
        coll.find().toArray { result in
            switch result {
            case .success(let documents):
                XCTAssertEqual([expectedDoc1, expectedDoc2], self.withoutIds(documents))
            case .failure:
                XCTFail("unexpected error in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should error with invalid filter")
        coll.updateMany(filter: ["$who": 1], update: [:]) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.mongoDBError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error code")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testWithCollectionType() {
        let coll = getTestColl().withCollectionType(CustomType.self)
        XCTAssertTrue(type(of: coll).CollectionType.self == CustomType.self)

        let expected = CustomType.init(id: "my_string_id", intValue: 42)

        var exp = expectation(description: "type should be able to be inserted")
        coll.insertOne(expected) { result in
            switch result {
            case .success(let insertResult):
                XCTAssertEqual(expected.id, insertResult.insertedId as? String)
            case .failure(let err):
                XCTFail("unexpected error in insert: \(err.localizedDescription)")
            }

            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        exp = expectation(description: "should be able to retrieve what was inserted")
        coll.find().first { result in
            switch result {
            case .success(let docResult):
                XCTAssertEqual(expected, docResult!)
            case .failure:
                XCTFail("unexpected error in find")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    func testSync_Count() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())
        sync.count(joiner.capture())

        XCTAssertEqual(2, joiner.value())

        sync.deleteMany(filter: ["a": "b"], joiner.capture())
        sync.count(joiner.capture())

        XCTAssertEqual(0, joiner.value())
    }

    func testSync_Find() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.find(filter: ["hello": "computer"], options: nil, joiner.capture())
        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
            XCTFail("documents not found")
            return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssertNotNil(actualDoc["_id"])
        XCTAssertEqual("computer", actualDoc["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testSync_Aggregate() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })
        let joiner = CallbackJoiner()
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        sync.insertMany(documents: [doc1, doc2], joiner.capture())
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.aggregate(
            pipeline: [
                ["$project": ["_id": 0, "a": 0] as Document],
                ["$match": ["hello": "computer"] as Document]
            ],
            options: nil,
            joiner.capture())

        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
                XCTFail("docs not inserted")
                return
        }

        XCTAssertNil(actualDoc["a"])
        XCTAssertNil(actualDoc["_id"])
        XCTAssertEqual("computer", actualDoc["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testSync_InsertOne() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b", documentVersionField: "naughty"] as Document

        sync.insertOne(document: doc1, joiner.capture())
        let insertOneResult = joiner.value(asType: SyncInsertOneResult.self)
        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())
        sync.find(filter: ["_id": insertOneResult?.insertedId ?? BSONNull()], options: nil, joiner.capture())

        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
                XCTFail("doc was not inserted")
                return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssert(bsonEquals(insertOneResult?.insertedId ?? nil, actualDoc["_id"]))
        XCTAssertEqual("world", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        XCTAssertNil(cursor.next())
    }

    func testSync_InsertMany() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        sync.insertMany(documents: [doc1, doc2], joiner.capture())
        let insertManyResult = joiner.value(asType: SyncInsertManyResult.self)

        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.find(filter: [
            "_id": ["$in": insertManyResult?.insertedIds.values.compactMap { $0 } ?? BSONNull() ] as Document],
                  joiner.capture())
        guard let cursor = joiner.capturedValue as? MongoCursor<Document>,
            let actualDoc = cursor.next() else {
                XCTFail("doc was not inserted")
                return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssert(bsonEquals(insertManyResult?.insertedIds[0] ?? nil, actualDoc["_id"]))
        XCTAssertEqual("world", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        XCTAssertNotNil(cursor.next())
    }

    func testSync_UpdateOne() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b", documentVersionField: "naughty"] as Document

        sync.updateOne(filter: doc1,
                       update: doc1,
                       options: SyncUpdateOptions(upsert: true),
                       joiner.capture())

        guard let insertedId = (joiner.capturedValue as? SyncUpdateResult)?.upsertedId else {
            XCTFail("doc not upserted")
            return
        }

        sync.updateOne(filter: ["_id": insertedId],
                       update: ["$set": ["hello": "goodbye"] as Document],
                       options: nil,
                       joiner.capture())

        guard let updateResult = joiner.capturedValue as? SyncUpdateResult else {
            XCTFail("failed to update doc")
            return
        }
        XCTAssertEqual(updateResult.matchedCount, 1)
        XCTAssertEqual(updateResult.modifiedCount, 1)
        XCTAssertNil(updateResult.upsertedId)

        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())

        sync.find(filter: ["_id": insertedId],
                  options: nil,
                  joiner.capture())

        guard let cursor = joiner.value(asType: MongoCursor<Document>.self),
            let actualDoc = cursor.next() else {
                XCTFail("doc was not inserted")
                return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssertEqual("goodbye", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        XCTAssertNil(cursor.next())
    }

    func testSync_UpdateMany() throws {
        let coll = getTestColl()
        let sync = coll.sync
        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        let doc1 = ["hello": "world", "a": "b", documentVersionField: "naughty"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        guard let insertManyResult = (joiner.capturedValue as? SyncInsertManyResult) else {
            XCTFail("insert failed")
            return
        }

        let insertedIds = insertManyResult.insertedIds.compactMap({ $0.value })
        sync.updateMany(filter: ["_id": ["$in": insertedIds] as Document],
                        update: ["$set": ["hello": "goodbye"] as Document],
                        options: nil,
                        joiner.capture())
        guard let updateResult = joiner.capturedValue as? SyncUpdateResult else {
            XCTFail("update failed")
            return
        }

        XCTAssertEqual(updateResult.matchedCount, 2)
        XCTAssertEqual(updateResult.modifiedCount, 2)
        XCTAssertNil(updateResult.upsertedId)

        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        sync.find(filter: ["_id": ["$in": insertedIds] as Document],
                  options: nil,
                  joiner.capture())
        guard let cursor = joiner.value(asType: MongoCursor<Document>.self) else {
            XCTFail("could not find documents")
            return
        }

        cursor.forEach { actualDoc in
            XCTAssertEqual("b", actualDoc["a"] as? String)
            XCTAssertEqual("goodbye", actualDoc["hello"] as? String)
            XCTAssertFalse(actualDoc.hasKey(documentVersionField))
        }
    }

    func testSync_deleteOne() throws {
        let coll = getTestColl()
        let sync = coll.sync

        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        // ensure that the test collection is empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // insert some test documents
        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["goodbye": "world", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        // ensure that the documents were inserted
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        // delete the { hello: "world" } document
        sync.deleteOne(filter: ["hello": "world"], joiner.capture())
        var deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(1, deleteResult?.deletedCount)

        // ensure that there is only one document, and that it is the { goodbye: "world" } one
        sync.count(joiner.capture())
        XCTAssertEqual(1, joiner.value())

        sync.count(filter: ["hello": "world"], options: nil, joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // delete the remaining document with empty filter
        sync.deleteOne(filter: [], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(1, deleteResult?.deletedCount)

        // collection should be empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // should not be able to delete any more documents
        sync.deleteOne(filter: [], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(0, deleteResult?.deletedCount)
    }

    func testSync_deleteMany() throws {
        let coll = getTestColl()
        let sync = coll.sync

        sync.configure(conflictHandler: { _, _, rDoc in rDoc.fullDocument },
                       changeEventDelegate: { _, _ in },
                       errorListener: { _, _ in })

        let joiner = CallbackJoiner()

        // ensure that the test collection is empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // insert some test documents
        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["goodbye": "world", "a": "b"] as Document
        sync.insertMany(documents: [doc1, doc2], joiner.capture())

        // ensure that the documents were inserted
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        // delete documents with a filter for which there are no documents
        sync.deleteMany(filter: ["a": "c"], joiner.capture())
        var deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(0, deleteResult?.deletedCount)

        // ensure nothing got deleted
        sync.count(joiner.capture())
        XCTAssertEqual(2, joiner.value())

        // delete all the documents we inserted
        sync.deleteMany(filter: ["a": "b"], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(2, deleteResult?.deletedCount)

        // collection should be empty
        sync.count(joiner.capture())
        XCTAssertEqual(0, joiner.value())

        // should not be able to delete any more documents
        sync.deleteMany(filter: [], joiner.capture())
        deleteResult = joiner.value(asType: SyncDeleteResult.self)
        XCTAssertEqual(0, deleteResult?.deletedCount)
    }
}

public struct CustomType: Codable {
    public let id: String
    public let intValue: Int

    public enum CodingKeys: String, CodingKey {
        case id = "_id", intValue
    }
}

extension CustomType: Equatable {
    public static func == (lhs: CustomType, rhs: CustomType) -> Bool {
        return lhs.id == rhs.id && lhs.intValue == rhs.intValue
    }
}
