import Foundation
import StitchCoreSDK

/// View into a specific application
public struct AppResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case name, id = "_id", clientAppID = "client_app_id"
    }

    /// unique, internal id of this application
    public let id: String
    /// name of this application
    public let name: String
    /// public, client app id (for `StitchClient`) of this application
    public let clientAppID: String
}

extension Apps {
    /// POST a new application
    /// - parameter name: name of the new application
    /// - parameter defaults: whether or not to enable default values
    public func create(name: String, defaults: Bool = false) throws -> AppResponse {
        let encodedApp = try JSONEncoder().encode(["name": name])
        let req = try StitchAuthRequestBuilder()
            .with(method: .post)
            .with(path: "\(self.url)?defaults=\(defaults)")
            .with(body: encodedApp)
            .build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)
        return try JSONDecoder().decode(AppResponse.self, from: response.body!)
    }

    /// GET an application
    /// - parameter id: id for the application
    public func app(withAppID appID: String) -> App {
        return App.init(adminAuth: self.adminAuth, url: "\(url)/\(appID)")
    }
}
