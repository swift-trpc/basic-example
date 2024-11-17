//
//  TodoViewModel.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation
import swift_trpc

class TodoViewModel: ObservableObject {
    private var trpcClient: TrpcClient
    
    @Published
    var todos: [TodoCodable]?
    
    @Published
    var stats: TodoStatsCodable?
    
    @Published
    var todoToggles: [Bool]
    
    @Published
    var addTodoAlertTodoTitle: String = ""
    
    @Published
    var isAddTodoAlertVisible: Bool = false

    init(trpcClient: TrpcClient) {
        self.trpcClient = trpcClient
        self.todoToggles = []
    }
    
    func resetTodos() {
        self.todos = nil
        self.stats = nil
    }
    
    func fetchTodosAndStats() async throws {
        let todosRequest = TrpcRequest(type: .query, path: "todo.all")
        let statsRequest = TrpcRequest(type: .query, path: "todo.stats")
        
        let requests: [TrpcRequestProtocol] = [
            todosRequest,
            statsRequest
        ]
        
        let batchResponse = try await self.trpcClient.executeBatch(requests: requests)
        
        let todosResult = try batchResponse.get(index: 0, responseType: [TodoCodable].self)
        let statsResult = try batchResponse.get(index: 1, responseType: TodoStatsCodable.self)
        
        if let todosResultData = todosResult.result, todosResult.error == nil {
            await MainActor.run {
                self.todos = todosResultData
                self.todoToggles = todosResultData.map({ $0.checked })
            }
        }
        
        if let statsResultData = statsResult.result, statsResult.error == nil {
            await MainActor.run {
                self.stats = statsResultData
            }
        }
    }
    
    func addToDo() async throws {
        let input = CreateTodoInputCodable(title: self.addTodoAlertTodoTitle)
        let request = TrpcInputfulRequest(type: .mutation, path: "todo.create", headers: [:], input: input)
        let result = try await self.trpcClient.execute(request: request, responseType: TrpcEmptyResult.self)
        
        if let error = result.error {
            print("Add to-do error: \(String(describing: error))")
            return
        }
        
        await MainActor.run {
            self.addTodoAlertTodoTitle = ""
        }
        
        try await fetchTodosAndStats()
    }
    
    func updateToDoState(id: Int, checked: Bool) async throws {
        let input = UpdateTodoCodable(id: id, checked: checked)
        let request = TrpcInputfulRequest(type: .mutation, path: "todo.update", input: input)
        let result = try await self.trpcClient.execute(request: request, responseType: TodoCodable.self)
        
        if let error = result.error {
            print("Error: \(String(describing: error))")
        }
        
        try await fetchTodosAndStats()
    }
}
