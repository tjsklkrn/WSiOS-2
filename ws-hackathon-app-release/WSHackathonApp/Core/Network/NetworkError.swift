//
//  NetworkError.swift
//  WSHackathonApp
//
//  Created by Nilesh Mahajan on 03/04/26.
//

import Foundation
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(Int)

    /// Thrown when a cart or registry request is attempted with no signed-in Firebase user,
    /// or when the Firebase ID token fetch fails.
    case unauthenticated(String)


}
