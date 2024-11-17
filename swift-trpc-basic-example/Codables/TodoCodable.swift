//
//  TodoCodable.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

struct TodoCodable: Codable, Identifiable {
    var id: Int
    var title: String
    var checked: Bool
}
