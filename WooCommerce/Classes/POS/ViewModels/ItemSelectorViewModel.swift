import Combine
import SwiftUI
import protocol Yosemite.POSItem
import protocol Yosemite.POSItemProvider

final class ItemSelectorViewModel: ObservableObject {
    let selectedItemPublisher: AnyPublisher<POSItem, Never>

    @Published private(set) var items: [POSItem] = []
    @Published private(set) var isSyncingItems: Bool = true

    private let itemProvider: POSItemProvider
    private let selectedItemSubject: PassthroughSubject<POSItem, Never> = .init()

    init(itemProvider: POSItemProvider) {
        self.itemProvider = itemProvider
        selectedItemPublisher = selectedItemSubject.eraseToAnyPublisher()
    }

    func select(_ item: POSItem) {
        selectedItemSubject.send(item)
    }

    @MainActor
    func populatePointOfSaleItems() async {
        isSyncingItems = true
        do {
            items = try await itemProvider.providePointOfSaleItems()
        } catch {
            DDLogError("Error on load while fetching product data: \(error)")
        }
        isSyncingItems = false
    }

    @MainActor
    func reload() async {
        isSyncingItems = true
        do {
            let newItems = try await itemProvider.providePointOfSaleItems()
            // Only clears in-memory items if the `do` block continues, otherwise we keep them in memory.
            items.removeAll()
            items = newItems
        } catch {
            DDLogError("Error on reload while updating product data: \(error)")
        }
        isSyncingItems = false
    }
}
