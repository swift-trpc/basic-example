//
//  TodoViewModelProtocol.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation

protocol TodoViewModelProtocol: ObservableObject {
    var todos: [TodoCodable]? { get }
    var stats: TodoStatsCodable? { get }
    var todoToggles: [Bool] { get set }
    var addTodoAlertTodoTitle: String { get set }
    var isAddTodoAlertVisible: Bool { get set }
    
    func resetTodos()
    func fetchTodosAndStats() async throws
    func addToDo() async throws
    func updateToDoState(id: Int, checked: Bool) async throws
}
