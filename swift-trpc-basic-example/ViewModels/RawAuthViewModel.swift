//
//  RawAuthViewModel.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation

class RawAuthViewModel: AuthViewModelProtocol {
    private let serverUrl: String
    private let session: URLSession
    private let defaults: UserDefaults
    
    @Published var username: String = ""
    @Published var currentUser: CurrentUserCodable?
    @Published var authenticated: Bool?
    
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
    
    init(serverUrl: String, session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.serverUrl = serverUrl
        self.session = session
        self.defaults = defaults
    }
    
    func fetchAuthentication() async throws {
        guard let token = authToken else {
            await MainActor.run {
                self.authenticated = false
            }
            return
        }
        
        guard let url = URL(string: "\(serverUrl)/auth.iam") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            await MainActor.run {
                self.authenticated = false
            }
            return
        }
        
        struct AuthResponse: Decodable {
            struct Result: Decodable {
                let data: CurrentUserCodable
            }
            let result: Result
        }
        
        let decodedResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        await MainActor.run {
            self.currentUser = decodedResponse.result.data
            self.authenticated = true
        }
    }
    
    func login() async throws {
        await MainActor.run {
            self.currentUser = nil
            self.authenticated = nil
        }
        
        guard let url = URL(string: "\(serverUrl)/auth.login") else {
            throw URLError(.badURL)
        }
        
        let loginInput = LoginInputCodable(username: username)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(loginInput)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            await MainActor.run {
                self.authenticated = false
            }
            return
        }
        
        struct LoginResponse: Decodable {
            struct Result: Decodable {
                let data: LoginResponseCodable
            }
            let result: Result
        }
        
        let decodedResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.authToken = decodedResponse.result.data.token
        
        try await fetchAuthentication()
    }
    
    func logout() {
        self.currentUser = nil
        self.authenticated = false
        self.authToken = nil
    }
}
