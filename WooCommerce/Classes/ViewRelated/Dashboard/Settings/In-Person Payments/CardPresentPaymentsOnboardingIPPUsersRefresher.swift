import CoreData
import Yosemite
import Storage
import Combine

/// Refreshes the CPP onboarding state if there are IPP transactions stored
///
class CardPresentPaymentsOnboardingIPPUsersRefresher {
    private let stores: StoresManager
    private let cardPresentPaymentsOnboardingUseCase: CardPresentPaymentsOnboardingUseCaseProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(stores: StoresManager = ServiceLocator.stores,
         cardPresentPaymentsOnboardingUseCase: CardPresentPaymentsOnboardingUseCaseProtocol = CardPresentPaymentsOnboardingUseCase()) {
        self.stores = stores
        self.cardPresentPaymentsOnboardingUseCase = cardPresentPaymentsOnboardingUseCase
    }

    func refreshIPPUsersOnboardingState(completion: @escaping (() -> Void)) {
        guard let siteID = stores.sessionManager.defaultStoreID else {
            return
        }

        let action = AppSettingsAction.loadSiteHasAtLeastOneIPPTransactionFinished(siteID: siteID) { [weak self] result in
            if result {
                guard let self else { return }

                self.cardPresentPaymentsOnboardingUseCase.statePublisher.sink { [weak self] state in
                    guard state != .loading else {
                        return
                    }
                    // Stop observing further state updates, to avoid memory cycles; this class is long-lived!
                    _ = self?.cancellables.map { $0.cancel() }
                    completion()
                }
                .store(in: &cancellables)

                self.cardPresentPaymentsOnboardingUseCase.refresh()
            }
        }

        stores.dispatch(action)
    }
}
