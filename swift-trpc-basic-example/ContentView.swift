//
//  ContentView.swift
//  swift-trpc-basic-example
//
//  Created by Artem Tarasenko on 17.11.2024.
//

import SwiftUI
import Combine
import swift_trpc

struct ContentView: View {
    let trpcClient: TrpcClientProtocol
    
    @ObservedObject
    var serverHealthViewModel: ServerHealthViewModel
    
    @ObservedObject
    var authViewModel: AuthViewModel
    
    @ObservedObject
    var todoViewModel: TodoViewModel
    
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        let trpcClient = TrpcClient(serverUrl: "http://localhost:8200")
        
        self.trpcClient = trpcClient
        self.serverHealthViewModel = ServerHealthViewModel(trpcClient: trpcClient)
        self.authViewModel = AuthViewModel(trpcClient: trpcClient)
        self.todoViewModel = TodoViewModel(trpcClient: trpcClient)
        
        self.authViewModel.$authenticated
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [self] value in
                if value != nil {
                    Task {
                        try await todoViewModel.fetchTodosAndStats()
                    }
                }
            }).store(in: &cancellables)
    }
    
    var body: some View {
        VStack {
            if let serverHealthy = serverHealthViewModel.serverHealthy {
                if serverHealthy {
                    HealthyServer
                } else {
                    ServerNotAvailable
                }
            } else {
                Text("Loading")
            }
        }
        .onAppear{
            Task {
                await serverHealthViewModel.fetchServerHealthy()
                
                guard let serverHealthy = serverHealthViewModel.serverHealthy, serverHealthy else {
                    return
                }
                
                try await authViewModel.fetchAuthentication()
                
                if let authenticated = self.authViewModel.authenticated, !authenticated {
                    return
                }
            }
        }
        .alert("Add To-Do", isPresented: $todoViewModel.isAddTodoAlertVisible, actions: {
            TextField("Name", text: $todoViewModel.addTodoAlertTodoTitle)
            Button("Add", action: {
                Task {
                    try await todoViewModel.addToDo()
                }
            })
            Button("Cancel", role: .cancel, action: {})
        })
        .padding()
    }
    
    var ServerNotAvailable: some View {
        Text("Server not available")
    }
    
    @ViewBuilder
    var HealthyServer: some View {
        if let authenticated = authViewModel.authenticated {
            if let currentUser = authViewModel.currentUser, authenticated {
                Authenticated(currentUser: currentUser)
            } else {
                Login
            }
        } else {
            Loading
        }
    }
    
    var Login: some View {
        VStack {
            Text("Secure Login").fontWeight(.bold)
            Spacer()
            TextField("Username", text: $authViewModel.username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.none)
            Spacer()
            Button(action: {
                print("Logging in...")
                Task {
                    try await authViewModel.login()
                }
            }, label: {
                Text("Log in").frame(maxWidth: .infinity)
            })
                .buttonStyle(.borderedProminent)
                .padding(4)
                .controlSize(.large)
        }
    }
    
    @ViewBuilder
    func Authenticated(currentUser: CurrentUserCodable) -> some View {
        VStack {
            HStack {
                Text("Hello, \(currentUser.username)!")
                Spacer()
                Button(action: {
                    authViewModel.logout()
                }, label: {
                    Text("Log out")
                })
            }
            TodoStats.safeAreaPadding(.vertical, 10)
            TodoList
            Spacer()
            Button(action: {
                todoViewModel.isAddTodoAlertVisible = true
            }, label: {
                Text("Add To-Do").frame(maxWidth: .infinity)
            })
                .buttonStyle(.borderedProminent)
                .padding(4)
                .controlSize(.large)
        }
    }
    
    @ViewBuilder
    var TodoStats: some View {
        HStack {
            if let todoStats = self.todoViewModel.stats {
                Text("Your stats:")
                Spacer()
                Text("\(todoStats.checked)/\(todoStats.total)")
            }
        }
    }
    
    @ViewBuilder
    var TodoList: some View {
        if let todos = self.todoViewModel.todos, todos.count > 0 {
            ForEach(Array(todos.enumerated()), id: \.offset) { (index, todo) in
                Toggle(isOn: $todoViewModel.todoToggles[index]) {
                    Text(todo.title)
                }.onChange(of: todoViewModel.todoToggles[index]) { newValue in
                    Task {
                        try await self.todoViewModel.updateToDoState(id: todo.id, checked: newValue)
                    }
                }
            }
        } else {
            Text("No To-Do's found")
        }
    }
    
    var Loading: some View {
        Text("Loading...")
    }
}

#Preview {
    ContentView()
}
