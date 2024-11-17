//
//  AuthViewModelProtocol.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation

protocol AuthViewModelProtocol: ObservableObject {
    var username: String { get set }
    var currentUser: CurrentUserCodable? { get }
    var authenticated: Bool? { get }
    var authToken: String? { get }

    func fetchAuthentication() async throws
    func login() async throws
    func logout()
}
