import StitchCoreSDK
import MongoSwift
import Foundation

/**
 * The implementation of the `StitchAppClient` protocol.
 */
internal final class StitchAppClientImpl: StitchAppClient, AuthMonitor {
    // MARK: Properties

    /**
     * The client's underlying authentication state, publicly exposed as a `StitchAuth` interface.
     */
    public var auth: StitchAuth {
        return _auth
    }

    /**
     * The client's underlying push notification component.
     */
    public lazy var push: StitchPush = StitchPushImpl.init(
        requestClient: self._auth,
        pushRoutes: self.routes.pushRoutes,
        dispatcher: self.dispatcher
    )

    /**
     * The client's underlying authentication state.
     */
    private var _auth: StitchAuthImpl

    /**
     * The core `CoreStitchAppClient` used by the client to make function call requests.
     */
    private let coreClient: CoreStitchAppClient

    /**
     * The operation dispatcher used to dispatch asynchronous operations made by this client and its underlying
     * objects.
     */
    private let dispatcher: OperationDispatcher

    /**
     * A `StitchAppClientInfo` describing the basic properties of this app client.
     */
    internal private(set) var info: StitchAppClientInfo

    /**
     * The API routes on the Stitch server to perform actions for this particular app.
     */
    private let routes: StitchAppRoutes

    // MARK: Initializer

    /**
     * Initializes the app client with the provided configuration, and with an operation dispatcher that runs on
     * the provided `DispatchQueue` (the default global `DispatchQueue` by default).
     */
    public init(withClientAppID clientAppID: String,
                withConfig config: ImmutableStitchAppClientConfiguration,
                withDispatchQueue queue: DispatchQueue = DispatchQueue.global()) throws {
        self.dispatcher = OperationDispatcher.init(withDispatchQueue: queue)
        self.routes = StitchAppRoutes.init(clientAppID: clientAppID)
        self.info = StitchAppClientInfo(
            clientAppID: clientAppID,
            dataDirectory: config.dataDirectory,
            localAppName: config.localAppName,
            localAppVersion: config.localAppVersion,
            networkMonitor: config.networkMonitor,
            authMonitor: nil)
        self._auth = try StitchAuthImpl.init(
            requestClient: StitchRequestClientImpl.init(baseURL: config.baseURL,
                                                        transport: config.transport,
                                                        defaultRequestTimeout: config.defaultRequestTimeout),
            authRoutes: self.routes.authRoutes,
            storage: config.storage,
            dispatcher: self.dispatcher,
            appInfo: self.info)
        self.coreClient = CoreStitchAppClient.init(authRequestClient: self._auth, routes: routes)
        self.info.authMonitor = self
    }

    // MARK: Services

    public func serviceClient(withServiceName serviceName: String) -> StitchServiceClient {
        return StitchServiceClientImpl.init(
            proxy: CoreStitchServiceClientImpl.init(
                requestClient: self._auth,
                routes: self.routes.serviceRoutes,
                serviceName: serviceName
            ),
            dispatcher: self.dispatcher
        )
    }

    public func serviceClient<T>(fromFactory factory: AnyNamedServiceClientFactory<T>,
                                 withName serviceName: String) -> T {
        return factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                         routes: self.routes.serviceRoutes,
                                                         serviceName: serviceName),
            withClientInfo: self.info
        )
    }

    public func serviceClient<T>(fromFactory factory: AnyNamedServiceClientFactory<T>) -> T {
        return factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                     routes: self.routes.serviceRoutes,
                                                     serviceName: nil),
            withClientInfo: self.info
        )
    }

    public func serviceClient<T>(fromFactory factory: AnyThrowingServiceClientFactory<T>) throws -> T {
        return try factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                         routes: self.routes.serviceRoutes,
                                                         serviceName: nil),
            withClientInfo: self.info
        )
    }

    func serviceClient<T>(fromFactory factory: AnyNamedThrowingServiceClientFactory<T>,
                          withName serviceName: String) throws -> T {
        return try factory.client(
            forService: CoreStitchServiceClientImpl.init(requestClient: self._auth,
                                                         routes: self.routes.serviceRoutes,
                                                         serviceName: serviceName),
            withClientInfo: self.info
        )
    }
    // MARK: Functions

    public func callFunction(withName name: String,
                             withArgs args: [BSONValue],
                             _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name, withArgs: args)
        }
    }

    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BSONValue],
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name,
                                                    withArgs: args)
        }
    }

    public func callFunction(withName name: String,
                             withArgs args: [BSONValue],
                             withRequestTimeout requestTimeout: TimeInterval,
                             _ completionHandler: @escaping (StitchResult<Void>) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name,
                                                    withArgs: args,
                                                    withRequestTimeout: requestTimeout
            )
        }
    }

    public func callFunction<T: Decodable>(withName name: String,
                                           withArgs args: [BSONValue],
                                           withRequestTimeout requestTimeout: TimeInterval,
                                           _ completionHandler: @escaping (StitchResult<T>) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.coreClient.callFunction(withName: name,
                                                    withArgs: args,
                                                    withRequestTimeout: requestTimeout)
        }
    }

    var isLoggedIn: Bool {
        return auth.isLoggedIn
    }
}
