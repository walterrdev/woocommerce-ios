import XCTest
@testable import WooCommerce
@testable import Networking

final class FreeTrialBannerViewModelTests: XCTestCase {

    /// All Expiry dates came in GMT from the API.
    ///
    private static let gmtTimezone = TimeZone(secondsFromGMT: 0) ?? .current
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = gmtTimezone
        return calendar
    }()

    func test_few_days_left_in_trial() {
        // Given
        let expiryDate = Date().adding(days: 3, using: Self.calendar)?.startOfDay(timezone: Self.gmtTimezone)
        let sitePlan = WPComSitePlan(hasDomainCredit: false, expiryDate: expiryDate)

        // When
        let viewModel = FreeTrialBannerViewModel(sitePlan: sitePlan)

        // Then
        XCTAssertEqual(viewModel.message, NSLocalizedString("3 days left in your trial.", comment: ""))
    }

    func test_1_day_left_in_trial() {
        // Given
        let expiryDate = Date().adding(days: 1, using: Self.calendar)?.startOfDay(timezone: Self.gmtTimezone)
        let sitePlan = WPComSitePlan(hasDomainCredit: false, expiryDate: expiryDate)

        // When
        let viewModel = FreeTrialBannerViewModel(sitePlan: sitePlan)

        // Then
        XCTAssertEqual(viewModel.message, NSLocalizedString("1 day left in your trial.", comment: ""))
    }

    func test_0_days_left_on_trial() {
        // Given
        let expiryDate = Date().startOfDay(timezone: Self.gmtTimezone)
        let sitePlan = WPComSitePlan(hasDomainCredit: false, expiryDate: expiryDate)

        // When
        let viewModel = FreeTrialBannerViewModel(sitePlan: sitePlan)

        // Then
        XCTAssertEqual(viewModel.message, NSLocalizedString("Your trial has ended.", comment: ""))
    }

    func test_no_days_left_on_trial() {
        // Given
        let expiryDate = Date().adding(days: -3, using: Self.calendar)?.startOfDay(timezone: Self.gmtTimezone)
        let sitePlan = WPComSitePlan(hasDomainCredit: false, expiryDate: expiryDate)

        // When
        let viewModel = FreeTrialBannerViewModel(sitePlan: sitePlan)

        // Then
        XCTAssertEqual(viewModel.message, NSLocalizedString("Your trial has ended.", comment: ""))
    }
}
