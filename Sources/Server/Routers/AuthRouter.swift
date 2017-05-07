import Foundation
import Kitura
import SwiftyJSON
import CryptoSwift
import MongoKitten

internal struct AuthActions {
    static private func findUser(with provider: PKSocialLoginProvider, userId: String, in collection: MongoKitten.Collection) throws -> PKUser? {
        let providerRawValue = provider.rawValue
        let query = [
            "links": [ "$elemMatch":
                [
                    "provider": providerRawValue,
                    "userId": userId
                ]
            ]
        ] as Query
        
        var result: Document? = nil
        do {
            result = try collection.findOne(query)
        } catch {
            throw PKServerError.databaseError(while: "trying to fetch your user data from collection.")
        }
        
        if result == nil { return nil }
        else { return PKUser.deserialize(from: result!) }
    }
    
    static func loginWithFacebook(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        // TODO: 支援其他 Scope
        
        let collection = request.database["users"]
        
        // 要求資料
        guard let body = request.body?.asJSON,
              let accessToken = body["accessToken"].string,
              let scope = body["scope"].string else {
            throw PKServerError.missingBody(fields: [])
        }
        
        if scope != "standard" {
            throw PKServerError.unimplementedError(feature: "agent and admin scope")
        }
        
        // 先確認使用者的 Claim
        var proof: String? = nil
        do {
            let hashed = try HMAC(key: PKResourceManager.shared.config.facebookSecret, variant: .sha256).authenticate(accessToken.toBytes())
            proof = Data(bytes: hashed).toHexString()
        } catch {
            throw PKServerError.cryptoError(while: "trying to hash your Facebook access token.")
        }
        
        var urlComponents = URLComponents(string: "https://graph.facebook.com/me")!
        urlComponents.queryItems = [
            URLQueryItem(name: "appsecret_proof", value: proof!),
            URLQueryItem(name: "access_token", value: accessToken)
        ]
        guard let url = urlComponents.url else {
            throw PKServerError.otherError(description: "Unable to create URL to confirm your identity.")
        }
        
        func `throw`(error: PKServerError) {
            response.error = error
            next()
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error -> Void in
            guard error == nil, let data = data else {
                `throw`(error: PKServerError.networkError(while: "confirming your identity with Facebook."))
                return
            }
            let body = JSON(data: data)
            guard let userId = body["id"].string  else {
                `throw`(error: .otherError(description: "Cannot deserialize response from Facebook while confirming your identity."))
                return
            }
            
            // 先找使用者是否存在
            var existingUser: PKUser? = nil
            do {
                existingUser = try AuthActions.findUser(with: .facebook, userId: userId, in: collection)
            } catch {
                `throw`(error: error as! PKServerError)
            }
            var token: String? = nil
            
            switch existingUser {
            case .none:
                // 沒找到，幫他註冊
                var user = PKUser(.standard, initialLink: PKSocialLoginLink(provider: .facebook, userId: userId, accessToken: accessToken))
                token = user.createNewToken(of: .standard).value
                
                // 放進資料庫
                let document = Document(user)
                do {
                    _ = try collection.insert(document)
                } catch {
                    `throw`(error: .databaseError(while: "saving your account to database."))
                    return
                }
            case .some(let user):
                let createdToken = existingUser!.createNewToken(of: .standard)
                token = createdToken.value
                let id = user._id!
                let update = [
                    "$push" : [
                        "tokens": Document(createdToken)
                    ]
                ] as Document
                let query: Query = "_id" == id
                do {
                    _ = try collection.findAndUpdate(query, with: update)
                } catch {
                    `throw`(error: .databaseError(while: "updating your account to database."))
                    return
                }
            }
            
            response.send(token!)
        }.resume()
    }
    
    static func addFacebookLink(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {}
    static func deleteFacebookLink(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {}
    static func deleteAccount(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {}
}

/**
 取得認證的路由：
 
 - 登入（`login`）相關路徑
   
   不必註冊即可登入
 
   + 使用 Facebook（`POST login/facebook`）
     
     必須在主體中帶有 `scope` 以及 `accessToken` 兩個鍵
 
 - 帳號（`account`）
   - 登入方法（`links`）
     + 新增 Facebook（`POST account/links/facebook`）
 
       必須在主體中帶有 `scope` 以及 `accessToken` 兩個鍵
 
     - 刪除 Facebook（`DELETE account/links/facebook/:facebookUserId`)
   - 刪除帳號（`DELETE account`）
 
 */
func authRouter() -> Router {
    let router = Router()
    
    router.all("login", allowPartialMatch: true, middleware: loginRouter())
    
    return router
}

fileprivate func loginRouter() -> Router {
    let router = Router()
    router.post("facebook", handler: AuthActions.loginWithFacebook)
    
    return router
}
