import XCTest
import TestKit
@testable import WooCommerce
@testable import Yosemite

final class PaymentReceiptEmailParameterDeterminerTests: XCTestCase {
    private var stores: MockStoresManager!

    override func setUp() {
        super.setUp()

        stores = MockStoresManager(sessionManager: SessionManager.makeForTesting())
        stores.whenReceivingAction(ofType: SystemStatusAction.self) { action in
            guard case let .synchronizeSystemPlugins(_, onCompletion) = action else {
                return
            }

            onCompletion(.success(()))
        }
    }

    override func tearDown() {
        stores = nil
    }

    func test_when_only_WCPay_is_active_and_version_is_higher_than_minimum_that_sends_email_then_returns_nil() {
        let order = Order.fake()
        let wcPayPlugin = SystemPlugin.fake().copy(version: "4.3.4")
        let cardPresentPluginsDataProvider = MockCardPresentPluginsDataProvider(wcPayPlugin: wcPayPlugin,
                                                                      bothPluginsInstalledAndActive: false,
                                                                      wcPayInstalledAndActive: true)
        let sut = PaymentReceiptEmailParameterDeterminer(cardPresentPluginsDataProvider: cardPresentPluginsDataProvider, stores: stores)

        let result: Result<String?, Error> = waitFor { promise in
            sut.receiptEmail(from: order) { result in
                promise(result)
            }
        }

        guard case let .success(email) = result else {
            XCTFail()
            return
        }

        XCTAssertNil(email)
    }

    func test_when_only_WCPay_is_active_and_version_is_equal_than_minimum_that_sends_email_then_returns_nil() {
        let wcPayPlugin = SystemPlugin.fake().copy(version: "4.0.0")
        let cardPresentPluginsDataProvider = MockCardPresentPluginsDataProvider(wcPayPlugin: wcPayPlugin,
                                                                      bothPluginsInstalledAndActive: false,
                                                                      wcPayInstalledAndActive: true)
        let sut = PaymentReceiptEmailParameterDeterminer(cardPresentPluginsDataProvider: cardPresentPluginsDataProvider, stores: stores)

        let result: Result<String?, Error> = waitFor { promise in
            sut.receiptEmail(from: Order.fake()) { result in
                promise(result)
            }
        }

        guard case let .success(email) = result else {
            XCTFail()
            return
        }

        XCTAssertNil(email)
    }

    func test_when_only_WCPay_is_active_and_version_is_lower_than_minimum_that_sends_email_then_returns_order_email() {
        let receiptEmail = "test@test.com"
        let billingAddress = Address.fake().copy(email: receiptEmail)
        let wcPayPlugin = SystemPlugin.fake().copy(version: "3.9.9")
        let cardPresentPluginsDataProvider = MockCardPresentPluginsDataProvider(wcPayPlugin: wcPayPlugin,
                                                                      bothPluginsInstalledAndActive: false,
                                                                      wcPayInstalledAndActive: true)
        let sut = PaymentReceiptEmailParameterDeterminer(cardPresentPluginsDataProvider: cardPresentPluginsDataProvider, stores: stores)

        let result: Result<String?, Error> = waitFor { promise in
            sut.receiptEmail(from: Order.fake().copy(billingAddress: billingAddress)) { result in
                promise(result)
            }
        }

        guard case let .success(returnedEmail) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(returnedEmail, receiptEmail)
    }

    func test_when_WCPay_and_Stripe_are_both_installed_and_active_then_returns_nil() {
        let cardPresentPluginsDataProvider = MockCardPresentPluginsDataProvider(bothPluginsInstalledAndActive: false)
        let sut = PaymentReceiptEmailParameterDeterminer(cardPresentPluginsDataProvider: cardPresentPluginsDataProvider, stores: stores)

        let result: Result<String?, Error> = waitFor { promise in
            sut.receiptEmail(from: Order.fake()) { result in
                promise(result)
            }
        }

        guard case let .success(email) = result else {
            XCTFail()
            return
        }

        XCTAssertNil(email)
    }

    func test_when_WCPay_is_not_active_then_returns_email() {
        let receiptEmail = "test@test.com"
        let billingAddress = Address.fake().copy(email: receiptEmail)
        let cardPresentPluginsDataProvider = MockCardPresentPluginsDataProvider(bothPluginsInstalledAndActive: false, wcPayInstalledAndActive: false)
        let sut = PaymentReceiptEmailParameterDeterminer(cardPresentPluginsDataProvider: cardPresentPluginsDataProvider, stores: stores)

        let result: Result<String?, Error> = waitFor { promise in
            sut.receiptEmail(from: Order.fake().copy(billingAddress: billingAddress)) { result in
                promise(result)
            }
        }

        guard case let .success(returnedEmail) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(returnedEmail, receiptEmail)
    }
}
