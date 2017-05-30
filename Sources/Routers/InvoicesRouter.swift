import Foundation
import Kitura
import MongoKitten
import SwiftyJSON
import LoggerAPI

// Internal Modules
import Models
import Middlewares
import Common
import ResourceManager
import Utilities


struct InvoiceActions {
    static func read(for user: PKUser, completionHandler: (_ preview: Result<JSON>) -> Void) {
        do {
            let invoices = try PKResourceManager.shared.database["invoices"]
                .find()
                .flatMap { $0.to(PKInvoice.self) }
                .filter { _ in true }
                .map { $0.detailedJSON }
            completionHandler(.success(JSON(invoices)))
        } catch {
            completionHandler(.error(PKServerError.database(while: "fetching invoices")))
        }
    }
    static func preview(for user: PKUser, completionHandler: (_ preview: Result<JSON>) -> Void) {
        do {
            let unpaidRecords = try PKResourceManager.shared.database["records"]
                .find("user.$id" == user._id! && "paid" == false)
                .flatMap { $0.to(PKRecord.self) }
                .filter { _ in true }
                .map { $0._id! }
            
            let invoice = PKInvoice(userId: user._id!, recordIds: unpaidRecords)
            completionHandler(.success(invoice.detailedJSON))
        } catch {
            completionHandler(.error(PKServerError.database(while: "fetching unpaid records")))
        }
    }
    static func create(for user: PKUser, completionHandler: (_ invoiceId: Result<String>) -> Void) {
        do {
            let unpaidRecords = try PKResourceManager.shared.database["records"]
                .find("user.$id" == user._id! && "paid" == false)
                .flatMap { $0.to(PKRecord.self) }
                .filter { _ in true }
                .map { $0._id! }
            
            let invoice = PKInvoice(userId: user._id!, recordIds: unpaidRecords)
            let insertedId = try PKResourceManager.shared.database["invoices"].insert(Document(invoice)).to(ObjectId.self)!
            
            _ = try PKResourceManager.shared.database["records"].update(["_id": ["$in": unpaidRecords] ], to: [ "$set": ["paid": true] ], upserting: false, multiple: true)
            
            completionHandler(.success(insertedId.hexString))
        } catch {
            completionHandler(.error(PKServerError.database(while: "fetching unpaid records")))
        }
    }
    static func paid(for id: ObjectId, completionHandler: (_ error: Result<Void>) -> Void) {
        do {
            _ = try PKResourceManager.shared.database["invoices"].update("_id" == id, to: [ "$set": ["paid": true] ])
            completionHandler(.success())
        } catch {
            completionHandler(.error(PKServerError.database(while: "fetching unpaid records")))
        }
    }
}

public func invoicesRouter() -> Router {
    let router = Router()
    
    router.get(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "preview next invoice", as: [.standard]), { req, res, next in
        InvoiceActions.read(for: req.user!) { result in
            switch result {
            case .success(let result):
                res.send(json: result)
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    router.get("next", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "preview next invoice", as: [.standard]), { req, res, next in
        InvoiceActions.preview(for: req.user!) { result in
            switch result {
            case .success(let result):
                res.send(json: result)
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    router.post(handler: AuthenticationMiddleware.mustBeAuthenticated(to: "preview next invoice", as: [.standard]), { req, res, next in
        InvoiceActions.create(for: req.user!) { result in
            switch result {
            case .success(let result):
                res.send(result)
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    router.post(":id/actions/pay", handler: AuthenticationMiddleware.mustBeAuthenticated(to: "preview next invoice", as: [.standard]), { req, res, next in
        guard let id = try? ObjectId(req.parameters["id"]!) else {
            throw PKServerError.deserialization(data: "ObjectId", while: "parsing URI")
        }
        guard let invoice = try PKResourceManager.shared.database["invoices"].findOne("_id" == id).to(PKInvoice.self) else {
            throw PKServerError.database(while: "checking that the invoice belongs to you")
        }
        if invoice._id! == req.user!._id! {
            throw PKServerError.unauthorized(to: "pay invoice off")
        }
        
        InvoiceActions.paid(for: id) { result in
            switch result {
            case .success():
                res.send("")
            case .error(let error):
                res.error = error
                next()
            }
        }
    })
    
    return router
}
