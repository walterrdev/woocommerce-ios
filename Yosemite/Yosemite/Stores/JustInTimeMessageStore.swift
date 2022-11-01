import Foundation
import Storage
import Networking

// MARK: - JustInTimeMessageStore
//
public class JustInTimeMessageStore: Store {
    private let remote: JustInTimeMessagesRemoteProtocol

    public override init(dispatcher: Dispatcher, storageManager: StorageManagerType, network: Network) {
        self.remote = JustInTimeMessagesRemote(network: network)
        super.init(dispatcher: dispatcher, storageManager: storageManager, network: network)
    }

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: JustInTimeMessageAction.self)
    }

    /// Receives and executes Actions.
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? JustInTimeMessageAction else {
            assertionFailure("JustInTimeMessageStore received an unsupported action")
            return
        }


        switch action {
        case .loadMessage(let siteID, let screen, let hook, let completion):
            loadMessage(for: siteID, screen: screen, hook: hook, completion: completion)
        case .dismissMessage(let message, let siteID, let completion):
            dismissMessage(message, for: siteID, completion: completion)
        }
    }
}

// MARK: - Services
//
private extension JustInTimeMessageStore {
    /// Retrieves the top `JustInTimeMessage` from the API for a given screen and hook
    ///
    func loadMessage(for siteID: Int64,
                     screen: String,
                     hook: JustInTimeMessageHook,
                     completion: @escaping (Result<YosemiteJustInTimeMessage?, Error>) -> ()) {
        Task {
            let result = await remote.loadAllJustInTimeMessages(
                    for: siteID,
                    messagePath: .init(app: .wooMobile,
                                       screen: screen,
                                       hook: hook))
            let displayResult = result.map(topDisplayMessage(_:))
            await MainActor.run {
                completion(displayResult)
            }
        }
    }

    func topDisplayMessage(_ messages: [Networking.JustInTimeMessage]) -> YosemiteJustInTimeMessage? {
        guard let topMessage = messages.first else {
            return nil
        }
        return YosemiteJustInTimeMessage(message: topMessage)
    }

    func dismissMessage(_ message: YosemiteJustInTimeMessage,
                        for siteID: Int64,
                        completion: @escaping (Result<Bool, Error>) -> ()) {
        Task {
            let result = await remote.dismissJustInTimeMessage(for: siteID,
                                                               messageID: message.messageID,
                                                               featureClass: message.featureClass)
            await MainActor.run {
                completion(result)
            }
        }
    }
}
