//
//  APIClient.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import Foundation
import UIKit
import FirebaseAuth


final class APIClient {
    static let shared = APIClient()
    private init() {}
    
    // MARK: - GET Request
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let (data, _) = try await requestData(endpoint)
        return try decode(data: data)
    }
    
    // MARK: - POST / PUT / PATCH Request (With Body)
    func request<T: Decodable, Body: Encodable>(
        _ endpoint: Endpoint,
        body: Body
    ) async throws -> T {
        let (data, _) = try await requestData(endpoint, body: body)
        return try decode(data: data)
    }
    
    // MARK: - Core Request
    private func requestData(
        _ endpoint: Endpoint,
        body: (any Encodable)? = nil
    ) async throws -> (Data, URLResponse) {
        
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = AppConstants.API.timeout

        endpoint.headers?.forEach {
            request.addValue($0.value, forHTTPHeaderField: $0.key)
        }
        

        // Firebase Auth — attach Bearer token for /cart/* and /registry/* endpoints
        if requiresFirebaseAuth(path: endpoint.path) {
            let token = try await fetchFirebaseIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        

        // Body (only if present)
        if let body = body {
            if endpoint.method == .get {
                assertionFailure("GET request should not have body")
            }
            
            request.httpBody = try encode(body)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        return (data, response)
    }
    

    // MARK: - Firebase Auth Helpers
    
    /// Returns `true` when the endpoint path requires a Firebase ID token.
    private func requiresFirebaseAuth(path: String) -> Bool {
        path.hasPrefix("/cart") || path.hasPrefix("/registry")
    }
    
    /// Fetches the current user's Firebase ID token using async/await.
    /// Throws `NetworkError.unauthenticated` if there is no signed-in user or the token fetch fails.
    private func fetchFirebaseIDToken() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NetworkError.unauthenticated("No signed-in Firebase user. Please sign in before accessing cart or registry.")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            currentUser.getIDToken { token, error in
                if let error = error {
                    continuation.resume(throwing: NetworkError.unauthenticated(
                        "Failed to retrieve Firebase ID token: \(error.localizedDescription)"
                    ))
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: NetworkError.unauthenticated(
                        "Firebase ID token was nil with no error."
                    ))
                }
            }
        }
    }
    

    // MARK: - Encode Helper (Fix for `any Encodable`)
    private func encode(_ value: any Encodable) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(AnyEncodable(value))
    }
    
    // MARK: - Decode Helper
    private func decode<T: Decodable>(data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    // MARK: - Image Download
    func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw NetworkError.decodingError
        }
        
        return image
    }
}

// MARK: - Type Erasure for Encodable
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        encodeFunc = value.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
