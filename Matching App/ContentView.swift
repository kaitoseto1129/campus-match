//
//  ContentView.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/29.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("ログイン成功")
            Button("ログアウト") {
                Task {
                    await auth.signOut()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

