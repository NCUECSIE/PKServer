import Common
import PKAutoSerialization
import Foundation
import CryptoSwift
import SwiftyJSON
import ResourceManager

public enum PKSocialStrategy: String, PKEnumReflectionSerializable {
    case facebook = "facebook"
    
    private static func getFacebookUserId(for accessToken: String, callback: @escaping (_ userId: String?, _ error: PKServerError?) -> Void) {
        // 1. 先確認使用者聲稱的權杖是否有效
        // 1.1 產生 appsecret_proof
        var proof: String! = nil
        do {
            let hashed = try HMAC(key: PKResourceManager.shared.config.facebookSecret, variant: .sha256).authenticate(accessToken.utf8.map({ $0 }))
            proof = Data(bytes: hashed).toHexString()
        } catch {
            callback(nil, PKServerError.crypto(while: "trying to hash your Facebook access token."))
            return
        }
        var urlComponents = URLComponents(string: "https://graph.facebook.com/me")!
        urlComponents.queryItems = [
            URLQueryItem(name: "appsecret_proof", value: proof!),
            URLQueryItem(name: "access_token", value: accessToken)
        ]
        guard let url = urlComponents.url else {
            callback(nil, PKServerError.unknown(description: "Unable to create URL to confirm your identity."))
            return
        }
        
        // 1.2 網路要求，呼叫 Facebook API
        URLSession.shared.dataTask(with: url) { data, _, error -> Void in
            guard error == nil, let data = data else {
                callback(nil, PKServerError.network(while: "confirming your identity with Facebook."))
                return
            }
            let body = JSON(data: data)
            guard let userId = body["id"].string  else {
                callback(nil, PKServerError.serialization(data: "from Facebook", while: "reading response from Facebook."))
                return
            }
            
            callback(userId, nil)
            }.resume()
    }
    
    public func validate(userId: String?, accessToken: String?, completionHandler: @escaping (_ credentials: (userId: String, accessToken: String)?, _ error: PKServerError?) -> Void) {
        switch self {
        case .facebook:
            guard let accessToken = accessToken else {
                completionHandler(nil, PKServerError.missingBody(fields: [(name: "accessToken", type: "String")]))
                return
            }
            
            PKSocialStrategy.getFacebookUserId(for: accessToken) { userId, error in
                switch (userId, error) {
                case (.none, .some(let err)):
                    completionHandler(nil, err)
                case (.some(let validatedUserId), _):
                    if let userId = userId {
                        if validatedUserId != userId {
                            completionHandler(nil, PKServerError.unknown(description: "User ID does not match Access Token."))
                            return
                        }
                    }
                    
                    completionHandler((userId: validatedUserId, accessToken: accessToken), nil)
                default:
                    completionHandler(nil, PKServerError.unknown(description: "Code path that is unreachable is reached."))
                }
            }
        }
    }
}
