//
//  ServerHealthViewModelProtocol.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation

protocol ServerHealthViewModelProtocol: ObservableObject {
    var serverHealthy: Bool? { get }
    
    func fetchServerHealthy() async
}
