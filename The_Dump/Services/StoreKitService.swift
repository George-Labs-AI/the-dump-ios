import Foundation
import StoreKit

class StoreKitService {
    static let shared = StoreKitService()

    static let subscriptionProductID = "12"

    private(set) var product: Product?
    private var transactionListenerTask: Task<Void, Never>?

    private init() {}

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.subscriptionProductID])
            product = products.first
#if DEBUG
            if let product {
                print("[StoreKitService] Loaded product: \(product.id) — \(product.displayPrice)")
            } else {
                print("[StoreKitService] No product found for ID: \(Self.subscriptionProductID)")
            }
#endif
        } catch {
#if DEBUG
            print("[StoreKitService] Failed to load products: \(error)")
#endif
        }
    }

    /// Initiates a purchase and returns the verified transaction with its JWS representation.
    /// The caller is responsible for calling `transaction.finish()` after backend verification.
    func purchase() async throws -> (transaction: Transaction, jwsRepresentation: String) {
        guard let product else {
            throw StoreKitError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            // Validate product ID before proceeding (spec Section 2)
            guard transaction.productID == Self.subscriptionProductID else {
                throw StoreKitError.unexpectedProduct(transaction.productID)
            }

            return (transaction, verification.jwsRepresentation)

        case .userCancelled:
            throw StoreKitError.userCancelled

        case .pending:
            throw StoreKitError.purchasePending

        @unknown default:
            throw StoreKitError.unknown
        }
    }

    func checkEntitlement() async -> (transaction: Transaction, jwsRepresentation: String)? {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.productID == Self.subscriptionProductID else {
                continue
            }
            return (transaction, result.jwsRepresentation)
        }
        return nil
    }

    func listenForTransactions(onTransaction: @escaping (Transaction, String) async -> Void) {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task.detached {
            for await result in Transaction.updates {
                guard let transaction = try? self.checkVerified(result) else { continue }
#if DEBUG
                print("[StoreKitService] Transaction update: \(transaction.productID) revoked=\(transaction.revocationDate != nil)")
#endif
                await onTransaction(transaction, result.jwsRepresentation)
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw StoreKitError.verificationFailed(error)
        }
    }
}

enum StoreKitError: LocalizedError {
    case productNotFound
    case userCancelled
    case purchasePending
    case unexpectedProduct(String)
    case verificationFailed(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not available"
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .unexpectedProduct(let id):
            return "Unexpected product: \(id)"
        case .verificationFailed(let error):
            return "Transaction verification failed: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
