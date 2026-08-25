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
    /// このUserDefaultsキーがtrueの間だけ、探す画面・マイページの初回チュートリアルを
    /// 出してよい対象とみなす。以前は「hasSeenXTutorial」フラグだけで制御していたが、
    /// これは端末側のフラグのため、アプリを削除して再インストールすると(Keychainに残っている
    /// セッションでログイン状態は復元されるのに)フラグだけリセットされてしまい、既存ユーザーの
    /// はずなのにチュートリアルが再度出てしまう不具合があった。signUp()完了時にだけこのキーを
    /// 立てることで、「本当に今サインアップした人」だけに対象を絞る。
    static let eligibleForOnboardingTutorialKey = "eligibleForOnboardingTutorial"
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: UUID?
    @Published var errorMessage: String?
    @Published var isLoading = false
    /// 起動直後の保存済みセッション確認が終わるまでtrue。
    /// これを見ずに描画すると、確認が終わるまでの一瞬だけログイン画面や空白が挟まってしまう。
    @Published var isRestoringSession = true
    /// メールアドレスの本人確認待ちのアドレス。
    /// Supabaseの「Confirm email」がONの間、サインアップ直後はセッションが発行されず、
    /// 確認コードを検証するまでログインできない。その待機状態をUIに伝えるために使う。
    @Published var pendingVerificationEmail: String?
    /// サインアップ→メール確認画面まで進んだ後に「戻る」で登録画面(AuthView)へ戻ると、
    /// AuthViewはビュー階層ごと作り直されて@Stateが初期化されてしまい、
    /// せっかく入力したメール・パスワード・表示名が全部消えていた。
    /// AuthViewを跨いで生き続けるこのAuthManager側に一時保持しておき、
    /// AuthViewの初期表示時に復元する。
    @Published var cachedSignUpEmail: String = ""
    @Published var cachedSignUpPassword: String = ""
    @Published var cachedSignUpDisplayName: String = ""

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
            // ログインフォームからのサインインは「既存アカウントである」ことが確定しているため、
            // 初回チュートリアル(探す画面・マイページ)は出さない。セッション自動復元(checkSession単体)は
            // ここを通らないため、進行中のチュートリアルを次回起動時に再開したい挙動には影響しない。
            UserDefaults.standard.set(true, forKey: "hasSeenDiscoverTutorial")
            UserDefaults.standard.set(true, forKey: "hasSeenMyPageTutorial")
        } catch let error {
            // メール未確認のまま(確認コード入力前にアプリを閉じた・SMTP遅延で届くのが遅れたなど)
            // ログインしようとした場合、以前は他の全エラーと同じ「パスワードが間違っています」に
            // なってしまい、本当の原因(メール未確認)も、確認画面へ戻る手段も分からなかった。
            // pendingVerificationEmailは再起動でリセットされてしまうため、ここで再度セットして
            // 確認コード入力画面に戻れるようにする。
            if let authError = error as? AuthError,
               case .api(_, let errorCode, _, _) = authError,
               errorCode == .emailNotConfirmed {
                pendingVerificationEmail = email
                errorMessage = "メールアドレスの確認が完了していません。届いた確認コードを入力してください。"
            } else {
                errorMessage = "メールアドレスまたはパスワードが間違っています"
            }
            print("sign in error: \(error)")
        }
        isLoading = false
    }
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        cachedSignUpEmail = email
        cachedSignUpPassword = password
        cachedSignUpDisplayName = displayName
        do {
            let response = try await supabase().auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )
            if response.session == nil {
                // 「Confirm email」がONの場合、この時点ではセッションが発行されない。
                // 確認コードを入力してもらうまでログインさせない。
                pendingVerificationEmail = email
            } else {
                await checkSession()
                UserDefaults.standard.set(true, forKey: Self.eligibleForOnboardingTutorialKey)
                clearCachedSignUpInput()
            }
        } catch let error {
            errorMessage = Self.describe(error)
            print("sign up error: \(error)")
        }
        isLoading = false
    }

    /// 登録したメールアドレス宛に届いた6桁の確認コードを検証し、本人確認を完了させる。
    /// 成功するとセッションが発行され、そのままログイン状態になる。
    @discardableResult
    func verifyEmailCode(_ code: String) async -> Bool {
        guard let email = pendingVerificationEmail else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase().auth.verifyOTP(
                email: email,
                token: code.trimmingCharacters(in: .whitespaces),
                type: .signup
            )
            await checkSession()
            if isAuthenticated {
                pendingVerificationEmail = nil
                UserDefaults.standard.set(true, forKey: Self.eligibleForOnboardingTutorialKey)
                clearCachedSignUpInput()
                return true
            }
            errorMessage = "確認に失敗しました。もう一度お試しください"
            return false
        } catch {
            errorMessage = Self.describeVerification(error)
            print("verify email code error: \(error)")
            return false
        }
    }

    /// 確認コードを再送する。
    @discardableResult
    func resendVerificationEmail() async -> Bool {
        guard let email = pendingVerificationEmail else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase().auth.resend(email: email, type: .signup)
            return true
        } catch {
            errorMessage = Self.describeVerification(error)
            print("resend verification error: \(error)")
            return false
        }
    }

    /// 本人確認を中断して登録画面に戻る。入力し直させないよう、
    /// キャッシュしておいたサインアップ内容はここでは消さない。
    func cancelEmailVerification() {
        pendingVerificationEmail = nil
        errorMessage = nil
    }

    private func clearCachedSignUpInput() {
        cachedSignUpEmail = ""
        cachedSignUpPassword = ""
        cachedSignUpDisplayName = ""
    }

    private static func describeVerification(_ error: Error) -> String {
        guard let authError = error as? AuthError, case .api(let message, let code, _, _) = authError else {
            return "確認に失敗しました。通信環境を確認してください"
        }
        switch code {
        case .otpExpired:
            return "コードの有効期限が切れています。再送してください"
        case .overEmailSendRateLimit:
            return "確認メールの送信が集中しています。しばらく待ってから再度お試しください"
        default:
            if message.localizedCaseInsensitiveContains("invalid") || message.localizedCaseInsensitiveContains("expired") {
                return "コードが正しくありません。もう一度ご確認ください"
            }
            return message
        }
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
                .update(["last_active_at": ISO8601DateFormatter.matchingApp.string(from: Date())])
                .eq("id", value: uid)
                .execute()
        } catch {
            print("touch last active error: \(error)")
        }
    }
    func signOut() async {
        isLoading = true
        await PushTokenManager.unregisterCurrentDevice()
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
        await PushTokenManager.unregisterCurrentDevice()
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


