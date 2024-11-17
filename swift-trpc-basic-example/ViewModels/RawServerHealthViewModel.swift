//
//  RawServerHealthService.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation

class RawServerHealthViewModel: ServerHealthViewModelProtocol {
   private let serverUrl: String
   private let session: URLSession
   
   @Published var serverHealthy: Bool?
   
   init(serverUrl: String, session: URLSession = .shared) {
       self.serverUrl = serverUrl
       self.session = session
   }
   
   func fetchServerHealthy() async {
       guard let url = URL(string: "\(serverUrl)/health") else {
           await MainActor.run {
               self.serverHealthy = false
           }
           return
       }
       
       var request = URLRequest(url: url)
       request.httpMethod = "GET"
       request.setValue("application/json", forHTTPHeaderField: "Content-Type")
       
       do {
           let (data, response) = try await session.data(for: request)
           
           guard let httpResponse = response as? HTTPURLResponse,
                 (200...299).contains(httpResponse.statusCode) else {
               await MainActor.run {
                   self.serverHealthy = false
               }
               return
           }
           
           struct HealthResponse: Decodable {
               struct Result: Decodable {
                   let data: HealthResponseCodable
               }
               let result: Result
           }
           
           let decodedResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
           
           await MainActor.run {
               self.serverHealthy = decodedResponse.result.data.healthy
           }
       } catch {
           await MainActor.run {
               self.serverHealthy = false
           }
       }
   }
}
