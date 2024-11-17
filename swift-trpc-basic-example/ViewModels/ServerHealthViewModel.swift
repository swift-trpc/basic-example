//
//  ServerHealthService.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation
import swift_trpc

class ServerHealthViewModel: ObservableObject {
    private let trpcClient: TrpcClientProtocol
    
    @Published
    var serverHealthy: Bool? = nil
    
    init(trpcClient: TrpcClientProtocol) {
        self.trpcClient = trpcClient
    }
    
    func fetchServerHealthy() async {
        let request = TrpcRequest(type: .query, path: "health")
        
        do {
            let response = try await self.trpcClient.execute(request: request, responseType: HealthResponseCodable.self)
            
            guard let result = response.result else {
                self.serverHealthy = false
                return
            }
            
            await MainActor.run {
                self.serverHealthy = result.healthy
            }
        } catch {
            print(error)
            self.serverHealthy = false
        }
    }
}
