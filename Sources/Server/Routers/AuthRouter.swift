import Foundation
import Kitura
import KituraNet
import SwiftyJSON
import CryptoSwift
import MongoKitten

fileprivate struct FacebookActions {
    static func getFacebookUserId(for accessToken: String, callback: @escaping (String?, PKServerError?) -> Void) {
        // 先確認使用者的 Claim
        var proof: String! = nil
        do {
            let hashed = try HMAC(key: PKResourceManager.shared.config.facebookSecret, variant: .sha256).authenticate(accessToken.toBytes())
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
    // TODO: 支援其他 Scope
    // TODO: 重新架構有關 Register 以及 Token 的部分
    /* 在其他 Scope 必須：
     - 使用者屬於該 Scope
     若是 agent scope 則當沒有選則 provider 時，將 provider 清單給他
     */
    static func loginOrRegisterWithFacebook(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        let collection = request.database["users"]
        
        // 要求資料
        guard let body = request.body?.asJSON,
            let accessToken = body["accessToken"].string,
            let scope = body["scope"].string else {
                throw PKServerError.missingBody(fields: [])
        }
        
        if scope != "standard" {
            throw PKServerError.unimplemented(feature: "agent and admin scope")
        }
        
        FacebookActions.getFacebookUserId(for: accessToken) { userId, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            
            guard let userId = userId else {
                response.error = PKServerError.unknown(description: "Logic error in server code.")
                next()
                return
            }
            
            // 先找使用者是否存在
            var existingUser: PKUser? = nil
            do {
                existingUser = try AuthActions.findUser(with: .facebook, userId: userId, in: collection)
            } catch {
                response.error = error
                next()
                return
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
                    response.error = error
                    next()
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
                    response.error = error
                    next()
                    return
                }
            }
            
            response.send(token!)
        }
    }
    
    /// - Precondition: `request.user != nil`
    static func addFacebookLink(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        // 檢查 --> 是否重複
        let collection = request.database["users"]
        
        // 要求資料
        guard let body = request.body?.asJSON,
            let accessToken = body["accessToken"].string else {
                throw PKServerError.missingBody(fields: [])
        }
        
        FacebookActions.getFacebookUserId(for: accessToken) { userId, error in
            if let error = error {
                response.error = error
                next()
                return
            }
            guard let userId = userId else {
                response.error = PKServerError.unknown(description: "Logic error in server code.")
                next()
                return
            }
            
            // 尋找該 Facebook 帳號是否已經在資料庫中
            do {
                if try AuthActions.findUser(with: .facebook, userId: userId, in: collection) != nil {
                    response.error = PKServerError.linkExisted
                    next()
                    return
                }
            } catch {
                response.error = error
                next()
                return
            }
            
            // 不在資料庫，加入到目前的使用者
            let userOId = request.user!._id!
            
            let query = "_id" == userOId
            let update = [
                "$push" : [
                    "links": Document(PKSocialLoginLink(provider: .facebook, userId: userId, accessToken: accessToken))
                ]
            ] as Document
            
            do {
                _ = try collection.findAndUpdate(query, with: update)
            } catch {
                response.error = PKServerError.database(while: "saving new link to database")
                next()
                return
            }
            
            response.status(HTTPStatusCode.created).send("")
        }
    }
    static func deleteFacebookLink(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        // 最後一個 Link 不可以透過這個方法刪除
        
    }
}

fileprivate struct AuthActions {
    static func findUser(with provider: PKSocialLoginProvider, userId: String, in collection: MongoKitten.Collection) throws -> PKUser? {
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
            throw PKServerError.database(while: "trying to fetch your user data from collection.")
        }
        
        if result == nil { return nil }
        else {
            guard let deserialized = PKUser.deserialize(from: result!) else {
                throw PKServerError.deserialization(data: "Users", while: "fetching your record from database.")
            }
            return deserialized
        }
    }
    static func deleteAccount(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {}
    static func inspect(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        var payload: [String: Primitive] = [ "loggedin": request.user != nil ]
        if let scope = request.authenticatedScope {
            payload["scope"] = scope.toDocument()!["case"]!
        }
        response.send(json: payload)
    }
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
    router.all("account", allowPartialMatch: true, middleware: accountRouter())
    router.get("", handler: AuthActions.inspect)
    return router
}

fileprivate func loginRouter() -> Router {
    let router = Router()
    router.post("facebook", handler: FacebookActions.loginOrRegisterWithFacebook)
    return router
}

fileprivate func accountRouter() -> Router {
    let router = Router()
    router.all("links", allowPartialMatch: true, middleware: linksRouter())
    
    router.delete(handler: AuthActions.deleteAccount)
    return router
}

fileprivate func linksRouter() -> Router {
    let router = Router()
    router.all("facebook", allowPartialMatch: true, middleware: facebookLinkRouter())
    return router
}

fileprivate func facebookLinkRouter() -> Router {
    let router = Router()
    
    router.post(handler: AuthenticationMiddleware.mustBeAuthenticated(for: "adding new facebook link"), FacebookActions.addFacebookLink)
    router.delete(":facebookUid", handler: AuthenticationMiddleware.mustBeAuthenticated(for: "removing facebook link"),FacebookActions.deleteFacebookLink)
    
    return router
}
