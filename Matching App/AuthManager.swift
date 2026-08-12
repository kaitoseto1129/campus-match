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
    /// 起動直後の保存済みセッション確認が終わるまでtrue。
    /// これを見ずに描画すると、確認が終わるまでの一瞬だけログイン画面や空白が挟まってしまう。
    @Published var isRestoringSession = true

    init() {
        Task {
            await checkSession()
            isRestoringSession = false
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
    /// GoogleやFacebookなどのOAuthプロバイダでサインイン/サインアップする。
    /// 動作させるには、(1)各社の開発者コンソールでのアプリ登録、(2)Supabase Dashboard > Authentication >
    /// ProvidersでのクライアントID/シークレット登録、(3)Xcode側でこのリダイレクトURLスキーム(campusmatch)を
    /// URL Typesに追加、の3つが別途必要。未設定の間はここでエラーになる。
    func signInWithOAuth(provider: Provider) async {
        isLoading = true
        errorMessage = nil
        do {
            guard let redirectURL = URL(string: "campusmatch://login-callback") else { return }
            try await supabase().auth.signInWithOAuth(provider: provider, redirectTo: redirectURL)
            await checkSession()
        } catch {
            errorMessage = "\(provider.rawValue.capitalized)ログインに失敗しました。提供者の設定が完了していない可能性があります。"
            print("oauth sign in error (\(provider)): \(error)")
        }
        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase().auth.signUp(email: email, password: password, data: ["display_name": .string(displayName)])
            await checkSession()
        } catch let error {
            errorMessage = Self.describe(error)
            print("sign up error: \(error)")
        }
        isLoading = false
    }

    /// サーバーから返るエラーコード・詳細メッセージを含めて具体的に表示する。
    private static func describe(_ error: Error) -> String {
        guard let authError = error as? AuthError else {
            return error.localizedDescription
        }
        switch authError {
        case .api(let message, let errorCode, _, _):
            if errorCode == .emailExists || errorCode == .userAlreadyExists
                || message.localizedCaseInsensitiveContains("already registered")
                || message.localizedCaseInsensitiveContains("already exists")
                || message.contains("既に登録") {
                return "このメールアドレスは既に登録されています。ログインしてください。"
            }
            return "\(message)(コード: \(errorCode.rawValue))"
        default:
            return authError.message
        }
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


