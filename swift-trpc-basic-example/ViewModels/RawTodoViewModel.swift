//
//  RawTodoViewModel.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import Foundation

class RawTodoViewModel: TodoViewModelProtocol {
   private let serverUrl: String
   private let session: URLSession
    public var authViewModel: (any AuthViewModelProtocol)?
   
   @Published var todos: [TodoCodable]?
   @Published var stats: TodoStatsCodable?
   @Published var todoToggles: [Bool] = []
   @Published var addTodoAlertTodoTitle: String = ""
   @Published var isAddTodoAlertVisible: Bool = false
   
    init(serverUrl: String, session: URLSession = .shared) {
       self.serverUrl = serverUrl
       self.session = session
   }
   
   func resetTodos() {
       self.todos = nil
       self.stats = nil
   }
   
   func fetchTodosAndStats() async throws {
       guard let url = URL(string: "\(serverUrl)/todo.all,todo.stats?batch=1") else {
           throw URLError(.badURL)
       }
       
       guard let authViewModel, let authToken = authViewModel.authToken else {
           return
       }

       var request = URLRequest(url: url)
       request.httpMethod = "GET"
       request.setValue("application/json", forHTTPHeaderField: "Content-Type")
       request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

       let queryInput = String(data: try JSONSerialization.data(withJSONObject: [:] as [String:Any]), encoding: .utf8)
       let urlWithQuery = url.appending(queryItems: [URLQueryItem(name: "input", value: queryInput)])
       request.url = urlWithQuery
       
       let (data, response) = try await session.data(for: request)
       
       guard let httpResponse = response as? HTTPURLResponse,
             (200...299).contains(httpResponse.statusCode) else {
           throw URLError(.badServerResponse)
       }
       
       struct TodoStatsResponse: Decodable {
           struct Result: Decodable {
               let data: TodoStatsCodable
           }
           
           let result: Result
       }
       
       struct TodosResponse: Decodable {
           struct Result: Decodable {
               let data: [TodoCodable]
           }
           
           let result: Result
       }

       guard let responses = try JSONSerialization.jsonObject(with: data) as? [Any] else {
           return
       }
       
       let todosData = try JSONSerialization.data(withJSONObject: responses[0])
       let statsData = try JSONSerialization.data(withJSONObject: responses[1])
       
       let decoder = JSONDecoder()
       
       let todos = try? decoder.decode(TodosResponse.self, from: todosData)
       let stats = try? decoder.decode(TodoStatsResponse.self, from: statsData)
       
       // And this code doesn't even account for errors
       // If there were error handling, it would be very bad to read
       
       await MainActor.run {
           if let todos = todos {
               self.todos = todos.result.data
               self.todoToggles = todos.result.data.map { $0.checked }
           }
           
           if let stats = stats {
               self.stats = stats.result.data
           }
       }
   }
   
   func addToDo() async throws {
       guard let url = URL(string: "\(serverUrl)/todo.create") else {
           throw URLError(.badURL)
       }
       
       guard let authViewModel, let authToken = authViewModel.authToken else {
           return
       }

       let input = CreateTodoInputCodable(title: addTodoAlertTodoTitle)
       
       var request = URLRequest(url: url)
       request.httpMethod = "POST"
       request.setValue("application/json", forHTTPHeaderField: "Content-Type")
       request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
       
       request.httpBody = try JSONEncoder().encode(input)
       
       let (data, response) = try await session.data(for: request)
       
       guard let httpResponse = response as? HTTPURLResponse,
             (200...299).contains(httpResponse.statusCode) else {
           throw URLError(.badServerResponse)
       }
       
       await MainActor.run {
           self.addTodoAlertTodoTitle = ""
       }
       
       try await fetchTodosAndStats()
   }
   
   func updateToDoState(id: Int, checked: Bool) async throws {
       guard let url = URL(string: "\(serverUrl)/todo.update") else {
           throw URLError(.badURL)
       }
       
       guard let authViewModel, let authToken = authViewModel.authToken else {
           return
       }

       let input = UpdateTodoCodable(id: id, checked: checked)
       
       var request = URLRequest(url: url)
       
       request.httpMethod = "POST"
       request.setValue("application/json", forHTTPHeaderField: "Content-Type")
       request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
       
       request.httpBody = try JSONEncoder().encode(input)
       
       let (data, response) = try await session.data(for: request)
       
       guard let httpResponse = response as? HTTPURLResponse,
             (200...299).contains(httpResponse.statusCode) else {
           throw URLError(.badServerResponse)
       }
       
       try await fetchTodosAndStats()
   }
}

