import Foundation
import Networking
import Storage

public final class CustomerStore: Store {

    private let customerRemote: CustomerRemote
    private let searchRemote: WCAnalyticsCustomerRemote

    init(dispatcher: Dispatcher,
         storageManager: StorageManagerType,
         network: Network,
         customerRemote: CustomerRemote,
         searchRemote: WCAnalyticsCustomerRemote) {
        self.customerRemote = customerRemote
        self.searchRemote = searchRemote

        super.init(dispatcher: dispatcher, storageManager: storageManager, network: network)
    }

    public override convenience init(dispatcher: Dispatcher,
                                     storageManager: StorageManagerType,
                                     network: Network) {
        self.init(dispatcher: dispatcher,
                  storageManager: storageManager,
                  network: network,
                  customerRemote: CustomerRemote(network: network),
                  searchRemote: WCAnalyticsCustomerRemote(network: network))
    }

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: CustomerAction.self)
    }

    /// Receives and executes Actions.
    ///
    /// - Parameters:
    ///   - action: An action to handle. Must be a `CustomerAction`
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? CustomerAction else {
            assertionFailure("CustomerStore received an unsupported action")
            return
        }
        switch action {
        case .searchCustomers(siteID: let siteID, keyword: let keyword, onCompletion: let onCompletion):
            searchCustomers(for: siteID, keyword: keyword, onCompletion: onCompletion)
        case .retrieveCustomer(siteID: let siteID, customerID: let customerID, onCompletion: let onCompletion):
            retrieveCustomer(for: siteID, with: customerID, onCompletion: onCompletion)
        }
    }

    /// Attempts to search Customers that match the given keyword, for a specific siteID.
    /// Returns Void upon success, or an Error.
    /// Search results are persisted in the local storage
    ///
    /// - Parameters:
    ///   - siteID: The site for which customers should be fetched.
    ///   - keyword: Keyword to perform the search for WCAnalyticsCustomer to be fetched.
    ///   - onCompletion: Invoked when the operation finishes.
    ///
    func searchCustomers(
        for siteID: Int64,
        keyword: String,
        onCompletion: @escaping (Result<Void, Error>) -> Void) {
            searchRemote.searchCustomers(for: siteID, name: keyword) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let customers):
                    print("1 - Successfully got [WCAnalyticsCustomer] array")
                    self.mapSearchResultsToCustomerObject(for: siteID, with: customers, onCompletion: onCompletion)
                case .failure(let error):
                    onCompletion(.failure(error))
                }
            }
        }

    /// Attempts to retrieve a single Customer from a site, returning the Customer object upon success, or an Error.
    /// The fetched Customer is persisted to the local storage.
    ///
    /// - Parameters:
    ///   - siteID: The site for which customers should be fetched.
    ///   - customerID: ID of the Customer to be fetched.
    ///   - onCompletion: Invoked when the operation finishes.
    ///
    func retrieveCustomer(
        for siteID: Int64,
        with customerID: Int64,
        onCompletion: @escaping (Result<Customer, Error>) -> Void) {
            customerRemote.retrieveCustomer(for: siteID, with: customerID) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let customer):
                    print("3 - Mapping -> Got the Customer: \(customer.customerID)")
                    self.upsertCustomer(siteID: siteID, readOnlyCustomer: customer, onCompletion: {})
                    onCompletion(.success(customer))
                case .failure(let error):
                    onCompletion(.failure(error))
                }
            }
        }

    /// Maps CustomerSearchResult to Customer objects
    ///
    /// - Parameters:
    ///   - siteID: The site for which customers should be fetched.
    ///   - searchResults: A WCAnalyticsCustomer collection that represents the matches we've got from the API based in our keyword search
    ///
    private func mapSearchResultsToCustomerObject(for siteID: Int64,
                                          with searchResults: [WCAnalyticsCustomer],
                                                  onCompletion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        print("2 - For each WCAnalyticsCustomer in [WCAnalyticsCustomer]...")
        for result in searchResults {
            group.enter()
            self.retrieveCustomer(for: siteID, with: result.userID, onCompletion: { result in
                print("Working with: \(String(describing: try? result.get()))")
                group.leave()
            })
        }
        group.notify(queue: .main) {
            self.upsertSearchCustomerResults(siteID: siteID, readOnlySearchResults: searchResults, onCompletion: {})
            print("Mapping done!")
            onCompletion(.success(()))
        }
    }

    /// Inserts or updates CustomerSearchResults in Storage
    ///
    private func upsertSearchCustomerResults(siteID: Int64, readOnlySearchResults: [Networking.WCAnalyticsCustomer], onCompletion: @escaping () -> Void) {
        for searchResult in readOnlySearchResults {
            // Logic for inserting or updating in Storage will go here.
            print("5 - Saving SearchResults: \(searchResult.userID) in Storage. Name: \(searchResult.name ?? "Name not found")")
        }
    }
    /// Inserts or updates Customers in Storage
    ///
    private func upsertCustomer(siteID: Int64, readOnlyCustomer: Networking.Customer, onCompletion: @escaping () -> Void) {
        // Logic for inserting or updating in Storage will go here.
        print("4 - Saving Customer: \(readOnlyCustomer.customerID) in Storage. Name: \(readOnlyCustomer.firstName ?? "Name not found")")
    }
}
