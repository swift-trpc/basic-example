//
//  AuthViewModel.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation
import swift_trpc

class AuthViewModel: AuthViewModelProtocol {
    private var trpcClient: TrpcClient
    private let defaults: UserDefaults

    @Published
    var username: String = ""
    
    @Published
    var currentUser: CurrentUserCodable?
    
    @Published
    var authenticated: Bool?
    
    public private(set) var authToken: String? {
        get { defaults.string(forKey: "auth_token") }
        set {
            if let value = newValue {
                defaults.set(value, forKey: "auth_token")
            } else {
                defaults.removeObject(forKey: "auth_token")
            }
        }
    }

    init(trpcClient: TrpcClient, defaults: UserDefaults = .standard) {
        self.trpcClient = trpcClient
        self.defaults = defaults
    }
    
    func fetchAuthentication() async throws {
        guard let authToken else {
            await MainActor.run {
                self.authenticated = false
            }
            return
        }
        
        let request = TrpcRequest(type: .query, path: "auth.iam", headers: ["Authorization": "Bearer \(authToken)"])
        let result = try await self.trpcClient.execute(request: request, responseType: CurrentUserCodable.self)
        
        if result.error != nil {
            print("Auth error: \(String(describing: result.error))")
            
            await MainActor.run {
                self.authenticated = false
            }
            return
        }

        guard let currentUser = result.result else {
            print("Auth no error but no user")
            
            await MainActor.run {
                self.authenticated = false
            }
            return
        }
        
        
        await MainActor.run {
            self.currentUser = currentUser
            self.authenticated = true
            
            trpcClient.baseHeaders["authorization"] = "Bearer \(authToken)"
        }
    }
    
    func login() async throws {
        await MainActor.run {
            self.currentUser = nil
            self.authenticated = nil
        }
        
        let input = LoginInputCodable(username: self.username)
        let request = TrpcInputfulRequest(type: .mutation, path: "auth.login", input: input)
        let result = try await self.trpcClient.execute(request: request, responseType: LoginResponseCodable.self)
        
        guard let loginResponse = result.result, result.error == nil else {
            print("Auth error: \(String(describing: result.error))")
            
            await MainActor.run {
                self.authenticated = false
            }
            return
        }
        
        self.authToken = loginResponse.token
        
        try await fetchAuthentication()
    }
    
    func logout() {
        self.currentUser = nil
        self.authenticated = false
        
        self.authToken = nil
        trpcClient.baseHeaders.removeValue(forKey: "authorization")
    }
}
