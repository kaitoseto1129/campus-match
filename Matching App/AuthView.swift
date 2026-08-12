//
//  AuthView.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/29.
//

import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject var auth: AuthManager
    @State var isSignUp = true
    @State var email: String = ""
    @State var password: String = ""
    @State var displayName: String = ""
    @State private var validDomains: [String] = []
    @State private var showingForgotPassword = false
    @State private var resetEmail = ""
    @State private var isSendingReset = false
    @State private var resetErrorMessage: String?
    @State private var showingResetSentAlert = false

    /// 大学ドメイン一覧の読み込みに失敗した場合は、誤ってサインアップをブロックしないよう検証をスキップする。
    var isEmailDomainValid: Bool {
        guard isSignUp, !validDomains.isEmpty else { return true }
        let lowered = email.lowercased()
        // 早稲田大学のように「@ruri.waseda.jp」等のサブドメインでメールを発行する大学もあるため、
        // 完全一致だけでなくサブドメイン一致も許可する(サーバー側のcheck_university_emailと同じ判定)。
        return validDomains.contains { domain in
            let d = domain.lowercased()
            return lowered.hasSuffix("@\(d)") || lowered.hasSuffix(".\(d)")
        }
    }
    var isFormValid: Bool {
        guard password.count >= 6 && email.contains("@") && isEmailDomainValid else {
            return false
        }
        if isSignUp {
            return !displayName.isEmpty
        }
        return true
    }
    var body: some View {
        Text("キャンパスマッチ")
            .font(.largeTitle.bold())
            .task {
                await loadValidDomains()
            }
        Text("大学メールアドレスで登録")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Picker("", selection: $isSignUp) {
            Text("新規登録").tag(true)
            Text("ログイン").tag(false)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 40)
        VStack {
            if isSignUp {
                TextField("表示名", text: $displayName)
            }
            TextField("メールアドレス", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("パスワード", text: $password)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 40)
        if isSignUp && !email.isEmpty && !isEmailDomainValid {
            Text("大学のメールアドレスで登録してください")
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        if let error = auth.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        Button {
            Task {
                if isSignUp {
                    await auth.signUp(email: email, password: password, displayName: displayName)
                } else {
                    await auth.signIn(email: email, password: password)
                }
            }
        } label: {
            Text(isSignUp ? "登録する" : "ログイン")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(.pink.opacity(isFormValid ? 1: 0.5))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 40)
        .disabled(!isFormValid || auth.isLoading)

        if !isSignUp {
            Button {
                resetEmail = email
                resetErrorMessage = nil
                showingForgotPassword = true
            } label: {
                Text("パスワードをお忘れの方はこちら")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }

        HStack {
            Rectangle().fill(Color(.systemGray4)).frame(height: 1)
            Text("または").font(.caption).foregroundStyle(.secondary)
            Rectangle().fill(Color(.systemGray4)).frame(height: 1)
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)

        VStack(spacing: 10) {
            socialLoginButton(title: "Googleで続ける", systemImage: "g.circle.fill") {
                Task { await auth.signInWithOAuth(provider: .google) }
            }
            socialLoginButton(title: "Facebookで続ける", systemImage: "f.circle.fill") {
                Task { await auth.signInWithOAuth(provider: .facebook) }
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 10)
        .disabled(auth.isLoading)

        EmptyView()
            .sheet(isPresented: $showingForgotPassword) {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("登録したメールアドレスにパスワード再設定用のリンクを送ります。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        TextField("メールアドレス", text: $resetEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let resetErrorMessage {
                            Text(resetErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Button {
                            Task { await sendPasswordReset() }
                        } label: {
                            Text("再設定メールを送信")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(.pink.opacity(resetEmail.contains("@") ? 1 : 0.5))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!resetEmail.contains("@") || isSendingReset)
                        Spacer()
                    }
                    .padding()
                    .padding(.top, 24)
                    .navigationTitle("パスワード再設定")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { showingForgotPassword = false }
                        }
                    }
                }
                .alert("送信しました", isPresented: $showingResetSentAlert) {
                    Button("OK") { showingForgotPassword = false }
                } message: {
                    Text("\(resetEmail) にパスワード再設定用のメールを送信しました。届いたメール内のリンクから再設定してください。")
                }
            }
    }

    private func socialLoginButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func sendPasswordReset() async {
        isSendingReset = true
        resetErrorMessage = nil
        do {
            try await supabase().auth.resetPasswordForEmail(resetEmail)
            showingResetSentAlert = true
        } catch {
            resetErrorMessage = "送信に失敗しました。メールアドレスをご確認ください。"
            print("reset password error: \(error)")
        }
        isSendingReset = false
    }

    private func loadValidDomains() async {
        do {
            struct DomainRow: Decodable { let domain: String }
            let rows: [DomainRow] = try await supabase()
                .from("universities")
                .select("domain")
                .execute()
                .value
            validDomains = rows.map(\.domain)
        } catch {
            print("university domain load error: \(error)")
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}


