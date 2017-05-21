import Foundation
import Kitura
import MongoKitten
import SwiftyJSON

// Internal Modules
import Models
import Middlewares
import Common
import ResourceManager

internal struct ProviderActions {
    /// 型態安全新增提供者的方法
    ///
    /// - Parameters:
    ///   - name: 提供者名稱
    ///   - type: 提供者類型
    ///   - completionHandler: 完成或是發生錯誤所呼叫的回呼
    ///   - insertedId: 若成功，新的唯一識別碼
    ///   - error: 若過程發生錯誤，錯誤物件
    static func create(name: String, type: PKProviderType, completionHandler: (_ insertedId: String?,_ error: PKServerError?) -> Void) {
        let provider = PKProvider(name: name, type: type)
        let document = Document(provider)
        
        let collection = PKResourceManager.shared.database["providers"]
        
        do {
            guard let id = try collection.insert(document).to(ObjectId.self) else {
                completionHandler(nil, .deserialization(data: "ObjectId", while: "reading inserted id from MongoKitten"))
                return
            }
            
            completionHandler(id.hexString, nil)
        } catch {
            completionHandler(nil, .database(while: "inserting information to database."))
        }
    }
    
    static func read(completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["providers"]
        
        do {
            var hasDeserializeError = false
            let providers = try collection.find().map({ (document: Document) -> PKProvider in
                guard let provider = PKProvider.deserialize(from: document) else {
                    hasDeserializeError = true
                    return PKProvider(name: "", type: .government)
                }
                return provider
            })
            
            if hasDeserializeError {
                completionHandler(nil, PKServerError.deserialization(data: "Provider", while: "deserializing BSON documents to Swift structures"))
            } else {
                let payload = providers.map { $0.simpleJSON }
                
                completionHandler(JSON(payload), nil)
            }
        } catch {
            completionHandler(nil, .database(while: "reading all documents in a collection"))
        }
    }
    
    static func read(id: ObjectId, completionHandler: (_ json: JSON?, _ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["providers"]
        do {
            guard let document = try collection.findOne("_id" == id) else {
                completionHandler(nil, .notFound)
                return
            }
            guard let provider = document.to(PKProvider.self) else {
                completionHandler(nil, PKServerError.deserialization(data: "Provider", while: "deserializing from database"))
                return
            }
            
            completionHandler(provider.detailedJSON, nil)
        } catch {
            completionHandler(nil, .database(while: "fetching document"))
        }
    }
    
    static func update(id: ObjectId, update: JSON, by: PKTokenScope, completionHandler: (_ error: PKServerError?) -> Void) {
        let collection = PKResourceManager.shared.database["providers"]
        var provider: PKProvider! = nil
        
        do {
            guard let document = try collection.findOne("_id" == id) else {
                completionHandler(.notFound)
                return
            }
            if let p = document.to(PKProvider.self) {
                provider = p
            } else {
                completionHandler(PKServerError.deserialization(data: "Provider", while: "deserializing from database"))
                return
            }
        } catch {
            completionHandler(.database(while: "fetching document"))
            return
        }
        
        if let name = update["name"].string {
            provider.name = name
        }
        if let typeString = update["type"].string,
            let type = PKProviderType(rawValue: typeString) {
            if type != provider.type {
                completionHandler(PKServerError.notImplemented(feature: "changing provider type"))
                return
            } // else continue!
        }
        
        let contactInformation = update["contactInformation"]
        
        if let phone = contactInformation["phone"].string {
            provider.contactInformation.phone = phone
        } else if let _ = contactInformation["phone"].null {
            provider.contactInformation.phone = nil
        }
        
        if let email = contactInformation["email"].string {
            provider.contactInformation.email = email
        } else if let _ = contactInformation["email"].null {
            provider.contactInformation.email = nil
        }
        if let address = contactInformation["address"].string {
            provider.contactInformation.address = address
        } else if let _ = contactInformation["address"].null {
            provider.contactInformation.address = nil
        }
        
        do {
            try collection.update("_id" == provider._id!, to: Document(provider))
            completionHandler(nil)
        } catch {
            completionHandler(.database(while: "updating provider"))
        }
    }
    
    static func delete(id: ObjectId, completionHandler: (_ error: PKServerError?) -> Void) {
        let spacesCollection = PKResourceManager.shared.database["spaces"]
        let providersCollection = PKResourceManager.shared.database["providers"]
        
        do {
            let spacesInProvider = try spacesCollection.count([ "provider.$id": id ])
            if spacesInProvider > 0 {
                completionHandler(PKServerError.unknown(description: "There are currently spaces in your provider. Please remove them first!"))
                return
            }
        } catch {
            print(error)
            completionHandler(.database(while: "checking if there are spaces in the provider"))
            return
        }
        
        do {
            try providersCollection.remove("_id" == id)
        } catch {
            completionHandler(.database(while: "removing the provider"))
            return
        }
        
        completionHandler(nil)
    }
    
    static func readSpaces(in provider: ObjectId, completionHandler: (_ spaces: JSON?, _ error: PKServerError?) -> Void) {
        let spacesCollection = PKResourceManager.shared.database["spaces"]
        
        do {
            let spaces = try spacesCollection.find("provider.$id" == provider).map({ space -> JSON in
                guard let space = PKSpace.deserialize(from: space)?.detailedJSON else {
                    throw PKServerError.deserialization(data: "Provider", while: "deserializing document from database")
                }
                return space
            })
            
            completionHandler(JSON(spaces), nil)
        } catch PKServerError.deserialization(data: let s, while: let w) {
            completionHandler(nil, .deserialization(data: s, while: w))
        } catch {
            completionHandler(nil, .database(while: "fetching data from MongoDB"))
        }
    }
}

public func providersRouter() -> Router {
    let router = Router()
    
    // 產生新的提供者必須為可讀寫的管理員
    router.post(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "add new provider", as: [PKUserType.admin(access: .readWrite)]), { req, res, next in
        guard let body = req.body?.asJSON,
            let name = body["name"].string,
            let typeString = body["type"].string,
            let type = PKProviderType(rawValue: typeString) else {
                throw PKServerError.missingBody(fields: [])
        }
        
        ProviderActions.create(name: name, type: type) { insertedId, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(insertedId!)
            }
        }
    })
    
    // 取得所有的提供者必須為管理員
    router.get("", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "read provider information", as: [PKUserType.admin(access: .readOnly)]), { req, res, next in
        ProviderActions.read { json, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: json!)
            }
        }
    })
    
    // 取得單一文件
    router.get(":id") { req, res, next in
        guard let oidString = req.parameters["id"],
            let oid = try? ObjectId(oidString) else {
                throw PKServerError.deserialization(data: "ObjectId", while: "converting URL parameter")
        }
        
        ProviderActions.read(id: oid) { json, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: json!)
            }
        }
    }
    
    router.get(":id/spaces", handler: { req, res, next in
        // 取得 Id
        guard let idString = req.parameters["id"],
            let id = try? ObjectId(idString) else {
                throw PKServerError.deserialization(data: "ObjectId", while: "converting URL parameter")
        }
        
        req.userInfo["id"] = id
        
        // 先進行驗證！
        let allowed = [PKUserType.admin(access: .readOnly), PKUserType.agent(provider: id, access: .readOnly)]
        let middleware = AuthenticationMiddleware.mustBeAuthenticated(to: "read provider information", as: allowed)
        do {
            try middleware(req, res, next)
        } catch {
            res.error = error
            next()
        }
    }, { req, res, next in
        let id = req.userInfo["id"] as! ObjectId
        ProviderActions.readSpaces(in: id) { json, error in
            if let error = error {
                res.error = error
                next()
            } else {
                res.send(json: json!)
            }
        }
    })
    
    // 只有管理員、提供者可以更新資料
    router.patch(":id", handler: { req, res, next in
        // 取得 Id
        guard let idString = req.parameters["id"],
            let id = try? ObjectId(idString) else {
                throw PKServerError.deserialization(data: "ObjectId", while: "converting URL parameter")
        }
        
        req.userInfo["id"] = id
        
        // 先進行驗證！
        let allowed = [PKUserType.admin(access: .readWrite), PKUserType.agent(provider: id, access: .readWrite)]
        let middleware = AuthenticationMiddleware.mustBeAuthenticated(to: "update provider information", as: allowed)
        do {
            try middleware(req, res, next)
        } catch {
            res.error = error
            next()
        }
    }, { req, res, next in
        let id = req.userInfo["id"] as! ObjectId
        guard let json = req.body?.asJSON else {
            res.error = PKServerError.missingBody(fields: [])
            next()
            return
        }
        
        var tokenScope: PKTokenScope! = nil
        if case .admin(_) = req.userType! {
            tokenScope = .admin
        } else if case .agent(_) = req.userType! {
            tokenScope = PKTokenScope.agent(provider: id)
        }
        
        ProviderActions.update(id: id, update: json, by: tokenScope) { err in
            if let err = err {
                res.error = err
                next()
            } else {
                res.send("")
            }
        }
    })
    
    router.delete(":id", handler: { req, res, next in
        // 取得 Id
        guard let idString = req.parameters["id"],
            let id = try? ObjectId(idString) else {
                throw PKServerError.deserialization(data: "ObjectId", while: "converting URL parameter")
        }
        
        req.userInfo["id"] = id
        
        // 先進行驗證！
        let allowed = [PKUserType.admin(access: .readWrite), PKUserType.agent(provider: id, access: .readWrite)]
        let middleware = AuthenticationMiddleware.mustBeAuthenticated(to: "delete provider information", as: allowed)
        do {
            try middleware(req, res, next)
        } catch {
            res.error = error
            next()
        }
    }, { req, res, next in
        let id = req.userInfo["id"] as! ObjectId
        
        ProviderActions.delete(id: id) { err in
            if let err = err {
                res.error = err
                next()
            } else {
                res.send("")
            }
        }
    })
    
    return router
}
