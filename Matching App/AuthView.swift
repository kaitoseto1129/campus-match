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
    @State private var isPasswordVisible = false
    @State var displayName: String = ""
    @State private var validDomains: [String] = []
    @State private var showingForgotPassword = false
    @State private var resetEmail = ""
    @State private var isSendingReset = false
    @State private var resetErrorMessage: String?
    @State private var showingResetSentAlert = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    /// マイページに辿り着く前(未登録・未ログイン状態)でも言語を選べるようにするための設定。
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue

    /// クリップボードからの貼り付けなどで前後に空白が混ざっていても弾かないようにする。
    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 大学ドメイン一覧の読み込みに失敗した場合は、誤ってサインアップをブロックしないよう検証をスキップする。
    var isEmailDomainValid: Bool {
        guard isSignUp, !validDomains.isEmpty else { return true }
        let lowered = trimmedEmail.lowercased()
        // 早稲田大学のように「@ruri.waseda.jp」等のサブドメインでメールを発行する大学もあるため、
        // 完全一致だけでなくサブドメイン一致も許可する(サーバー側のcheck_university_emailと同じ判定)。
        return validDomains.contains { domain in
            let d = domain.lowercased()
            return lowered.hasSuffix("@\(d)") || lowered.hasSuffix(".\(d)")
        }
    }
    var isFormValid: Bool {
        guard password.count >= 6 && trimmedEmail.contains("@") && isEmailDomainValid else {
            return false
        }
        if isSignUp {
            return !displayName.isEmpty
        }
        return true
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appListBackground.ignoresSafeArea()

            HStack {
                Spacer()
                languageToggle
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 28)
                    header
                    modeSwitcher
                    formFields
                    errorMessages
                    primaryButton

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
                    }

                    if isSignUp {
                        universityMailNote
                        termsAgreementNote
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            await loadValidDomains()
        }
        .onAppear {
            // メール確認画面から「戻る」で再びこの画面が作られた時、入力し直させないよう
            // AuthManagerに一時保持しておいたサインアップ内容を復元する。
            if !auth.cachedSignUpEmail.isEmpty {
                email = auth.cachedSignUpEmail
                password = auth.cachedSignUpPassword
                displayName = auth.cachedSignUpDisplayName
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            forgotPasswordSheet
        }
    }

    private var languageToggle: some View {
        Menu {
            Picker("", selection: $appLanguageRaw) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text("言語 / Language")
            }
            .font(.caption.bold())
            .foregroundStyle(Color.brandPurple)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brandPurple.opacity(0.12), in: Capsule())
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.brandPurple.opacity(0.35), radius: 12, y: 6)
            Text("キャンマッチ")
                .font(.title2.bold())
            Text("大学メールアドレスで登録")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var modeSwitcher: some View {
        Picker("", selection: $isSignUp) {
            Text("新規登録").tag(true)
            Text("ログイン").tag(false)
        }
        .pickerStyle(.segmented)
    }

    private var formFields: some View {
        VStack(spacing: 12) {
            if isSignUp {
                TextField("表示名", text: $displayName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            TextField("メールアドレス", text: $email)
                .textFieldStyle(.plain)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            if isSignUp && email.isEmpty {
                Text("大学から発行されたメールアドレス(例: your_name@university.ac.jp)で登録してください")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            HStack {
                Group {
                    if isPasswordVisible {
                        TextField("パスワード", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("パスワード", text: $password)
                    }
                }
                .textFieldStyle(.plain)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(isPasswordVisible ? "パスワードを隠す" : "パスワードを表示")
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private var errorMessages: some View {
        if isSignUp && !email.isEmpty && !isEmailDomainValid {
            Text("大学のメールアドレスで登録してください")
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
        if let error = auth.errorMessage {
            Text(LocalizedStringKey(error))
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var primaryButton: some View {
        Button {
            guard !auth.isLoading else { return }
            auth.isLoading = true
            Task {
                if isSignUp {
                    await auth.signUp(email: trimmedEmail, password: password, displayName: displayName)
                } else {
                    await auth.signIn(email: trimmedEmail, password: password)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if auth.isLoading {
                    ProgressView().tint(.white)
                }
                Text(isSignUp ? "登録する" : "ログイン")
                    .bold()
            }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isFormValid ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color(.systemGray4)))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .disabled(!isFormValid || auth.isLoading)
    }

    private var universityMailNote: some View {
        Text("大学生専用のアプリのため、学校のメールアドレスでご登録ください")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    /// 登録前に利用規約・プライバシーポリシーを確認できるようにする(App Store審査の一般的な要件)。
    /// 外部URLは公開状況によっては開けないため、アプリ内の画面をシートで開く。
    private var termsAgreementNote: some View {
        VStack(spacing: 6) {
            Text("登録すると、以下に同意したものとみなされます")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Button("利用規約") { showingTerms = true }
                Text("・").foregroundStyle(.secondary)
                Button("プライバシーポリシー") { showingPrivacy = true }
            }
            .font(.caption2.bold())
            .tint(Color.brandPurple)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .sheet(isPresented: $showingTerms) {
            NavigationStack {
                LegalDocumentView(document: .terms)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showingTerms = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            NavigationStack {
                LegalDocumentView(document: .privacy)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showingPrivacy = false }
                        }
                    }
            }
        }
    }

    private var forgotPasswordSheet: some View {
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
                    Text(LocalizedStringKey(resetErrorMessage))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await sendPasswordReset() }
                } label: {
                    Text("再設定メールを送信")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandPurple.opacity(resetEmail.contains("@") ? 1 : 0.5))
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
