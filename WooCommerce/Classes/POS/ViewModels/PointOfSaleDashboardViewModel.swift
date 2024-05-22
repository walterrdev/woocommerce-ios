import SwiftUI

final class PointOfSaleDashboardViewModel: ObservableObject {
    @Published var products: [POSProduct]
    @Published var productsInCart: [CartProduct] = []

    @Published var showsCardReaderSheet: Bool = false
    @Published var showsFilterSheet: Bool = false
    @ObservedObject private(set) var cardReaderConnectionViewModel: CardReaderConnectionViewModel

    enum OrderStage {
        case building
        case finalizing
    }

    @Published private(set) var orderStage: OrderStage = .building

    init(products: [POSProduct],
         cardReaderConnectionViewModel: CardReaderConnectionViewModel) {
        self.products = products
        self.cardReaderConnectionViewModel = cardReaderConnectionViewModel
    }

    func addProductToCart(_ product: POSProduct) {
        if product.stockQuantity > 0 {
            reduceInventory(product)

            let cartProduct = CartProduct(id: UUID(), product: product, quantity: 1)
            productsInCart.append(cartProduct)
        } else {
            // TODO: Handle out of stock
            // wp.me/p91TBi-bcW#comment-12123
            return
        }
    }

    func reduceInventory(_ product: POSProduct) {
        guard let index = products.firstIndex(where: { $0.itemID == product.itemID }) else {
            return
        }
        let updatedQuantity = product.stockQuantity - 1
        let updatedProduct = POSProduct(itemID: product.itemID,
                                    productID: product.productID,
                                    name: product.name,
                                    price: product.price,
                                    stockQuantity: updatedQuantity)
        products[index] = updatedProduct
    }

    func restoreInventory(_ product: POSProduct) {
        guard let index = products.firstIndex(where: { $0.itemID == product.itemID }) else {
            return
        }
        let updatedQuantity = product.stockQuantity + 1
        let updatedProduct = POSProduct(itemID: product.itemID,
                                    productID: product.productID,
                                    name: product.name,
                                    price: product.price,
                                    stockQuantity: updatedQuantity)
        products[index] = updatedProduct
    }

    // Removes a `CartProduct` from the Cart
    func removeProductFromCart(_ cartProduct: CartProduct) {
        productsInCart.removeAll(where: { $0.id == cartProduct.id })

        // When removing an item from the cart, restore previous inventory
        guard let match = products.first(where: { $0.productID == cartProduct.product.productID }) else {
            return
        }
        restoreInventory(match)
    }

    func submitCart() {
        // TODO:
        // Dummy toggle state. Should go only one-way building -> finalizing
        if orderStage == .building {
            orderStage = .finalizing
        } else {
            orderStage = .building
        }
    }

    func showCardReaderConnection() {
        showsCardReaderSheet = true
    }

    func showFilters() {
        showsFilterSheet = true
    }
}

extension PointOfSaleDashboardViewModel {
    // Helper function to populate SwifUI previews
    static func defaultPreview() -> PointOfSaleDashboardViewModel {
        PointOfSaleDashboardViewModel(products: [], cardReaderConnectionViewModel: .init(state: .connectingToReader))
    }
}
