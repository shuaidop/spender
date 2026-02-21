import Foundation

final class PlaidService: Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func createLinkToken(deviceToken: String) async throws -> String {
        let response: CreateLinkTokenResponse = try await apiClient.post(
            path: "/api/plaid/create-link-token",
            body: CreateLinkTokenRequest(deviceToken: deviceToken),
            deviceToken: deviceToken
        )
        return response.linkToken
    }

    func exchangeToken(publicToken: String, deviceToken: String) async throws -> ExchangeTokenResponse {
        try await apiClient.post(
            path: "/api/plaid/exchange-token",
            body: ExchangeTokenRequest(publicToken: publicToken, deviceToken: deviceToken),
            deviceToken: deviceToken
        )
    }

    func syncTransactions(deviceToken: String, itemId: String, cursor: String?) async throws -> SyncTransactionsResponse {
        try await apiClient.post(
            path: "/api/plaid/sync-transactions",
            body: SyncTransactionsRequest(deviceToken: deviceToken, itemId: itemId, cursor: cursor),
            deviceToken: deviceToken
        )
    }

    func disconnect(deviceToken: String, itemId: String) async throws {
        try await apiClient.delete(
            path: "/api/plaid/disconnect?itemId=\(itemId)",
            deviceToken: deviceToken
        )
    }
}
