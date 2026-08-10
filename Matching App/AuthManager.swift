//
//  AuthManager.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/29.
//

import Foundation
import Supabase
import Combine

@MainActor
final class AuthManager : ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: UUID?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    init() {
        Task {
            await checkSession()
        }
    }
    func checkSession() async {
        do {
            let session = try await supabase().auth.session
            currentUserId = session.user.id
            isAuthenticated = true
            await touchLastActive()
        } catch {
            isAuthenticated = false
        }
    }
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase().auth.signIn(email: email, password: password)
            await checkSession()
        } catch let error {
            errorMessage = "メールアドレスまたはパスワードが間違っています"
            print("sign in error: \(error)")
        }
        isLoading = false
    }
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        do {
            try await supabase().auth.signUp(email: email, password: password, data: ["display_name": .string(displayName)])
            await checkSession()
        } catch let error {
            errorMessage = error.localizedDescription

        }
        isLoading = false
    }
    func touchLastActive() async {
        guard let uid = currentUserId ?? supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("profiles")
                .update(["last_active_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: uid)
                .execute()
        } catch {
            print("touch last active error: \(error)")
        }
    }
    func signOut() async {
        isLoading = true
        do {
            try await supabase().auth.signOut()
            isAuthenticated = false
            currentUserId = nil
        } catch let error {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    func deleteAccount() async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase().rpc("delete_own_account").execute()
            try? await supabase().auth.signOut()
            isAuthenticated = false
            currentUserId = nil
            isLoading = false
            return true
        } catch {
            errorMessage = "退会処理に失敗しました"
            print("delete account error: \(error)")
            isLoading = false
            return false
        }
    }
}


