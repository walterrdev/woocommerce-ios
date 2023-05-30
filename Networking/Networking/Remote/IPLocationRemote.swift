import Foundation

/// Remote type to fetch the user's IP Location using a 3rd party API.
///
public final class IPLocationRemote: Remote {

    /// Fetches the country code from the device ip.
    ///
    public func getIPCountryCode(onCompletion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://ipinfo.io/json") else {
            return onCompletion(.failure(IPLocationError.malformedURL)) // Should not happen.
        }

        let request = UnauthenticatedRequest(request: .init(url: url))
        let mapper = IPCountryCodeMapper()
        enqueue(request, mapper: mapper, completion: onCompletion)
    }
}

/// `IPLocationRemote` known errors
///
public extension IPLocationRemote {
    enum IPLocationError: Error {
        case malformedURL
    }
}

/// Private mapper used to extract the country code from the `IPLocationRemote` response.
///
private struct IPCountryCodeMapper: Mapper {

    /// Response envelope
    ///
    struct Response: Decodable {
        enum CodingKeys: String, CodingKey {
            case countryCode = "country"
        }

        let countryCode: String
    }

    func map(response: Data) throws -> String {
        try JSONDecoder().decode(Response.self, from: response).countryCode
    }
}
