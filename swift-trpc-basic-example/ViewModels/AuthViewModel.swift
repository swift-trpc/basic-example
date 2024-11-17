//
//  AuthViewModel.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation
import swift_trpc

class AuthViewModel: ObservableObject {
    private var trpcClient: TrpcClient
    
    @Published
    var username: String = ""
    
    @Published
    var currentUser: CurrentUserCodable?
    
    @Published
    var authenticated: Bool?
    
    init(trpcClient: TrpcClient) {
        self.trpcClient = trpcClient
    }
    
    func fetchAuthentication() async throws {
        guard let authToken = UserDefaults.standard.string(forKey: "auth_token") else {
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
        
        UserDefaults.standard.set(loginResponse.token, forKey: "auth_token")
        
        try await fetchAuthentication()
    }
    
    func logout() {
        self.currentUser = nil
        self.authenticated = false
        
        UserDefaults.standard.removeObject(forKey: "auth_token")
        trpcClient.baseHeaders.removeValue(forKey: "authorization")
    }
}
