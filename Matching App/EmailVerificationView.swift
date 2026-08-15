//
//  EmailVerificationView.swift
//  Matching App
//

import SwiftUI

/// 新規登録の直後に、登録した大学メールアドレス宛に届く6桁の確認コードを入力してもらう画面。
/// ここを通らないとセッションが発行されないため、在学中の本人であることの確認になる。
///
/// Supabase側の前提:
///   Authentication > Sign In / Providers > Email の「Confirm email」がON であること。
///   Authentication > Emails > Confirm signup のテンプレートに {{ .Token }} が含まれていること
///   (既定のテンプレートはリンク{{ .ConfirmationURL }}のみでコードが載らないため、コードが届かない)。
struct EmailVerificationView: View {
    @EnvironmentObject private var auth: AuthManager
    let email: String

    @State private var code = ""
    @State private var showingResentToast = false
    @State private var secondsUntilResend = 0
    @FocusState private var isCodeFieldFocused: Bool

    private let codeLength = 6
    private var isCodeComplete: Bool { code.count == codeLength }

    var body: some View {
        ZStack {
            Color.appListBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    codeField
                    if let error = auth.errorMessage {
                        Text(LocalizedStringKey(error))
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    verifyButton
                    resendButton
                    notReceivedNote
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("戻る") { auth.cancelEmailVerification() }
            }
        }
        .onAppear {
            isCodeFieldFocused = true
            startResendCountdown()
        }
        .sentConfirmationCover(isPresented: $showingResentToast, message: "確認コードを再送しました", icon: "envelope.fill")
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 46))
                .foregroundStyle(Color.brandPurple)
                .padding(24)
                .background(Color.brandPurple.opacity(0.12), in: Circle())

            Text("メールアドレスの確認")
                .font(.title3.bold())

            VStack(spacing: 6) {
                Text("下記のアドレスに6桁の確認コードを送りました")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(email)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brandPurple)
                    .multilineTextAlignment(.center)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var codeField: some View {
        VStack(spacing: 10) {
            // 実際の入力は透明なTextFieldで受け、見た目は6つの枠で表現する。
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isCodeFieldFocused)
                    .opacity(0.01)
                    .onChange(of: code) { _, newValue in
                        // 数字以外と桁あふれを弾く。
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue || digits.count > codeLength {
                            code = String(digits.prefix(codeLength))
                        }
                    }

                HStack(spacing: 10) {
                    ForEach(0..<codeLength, id: \.self) { index in
                        digitBox(at: index)
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { isCodeFieldFocused = true }
        }
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(code)
        let isFilled = index < characters.count
        let isCurrent = index == characters.count && isCodeFieldFocused
        return RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .frame(height: 58)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Color.brandPurple : Color(.systemGray4), lineWidth: isCurrent ? 2 : 1)
            }
            .overlay {
                if isFilled {
                    Text(String(characters[index]))
                        .font(.title2.bold())
                }
            }
    }

    private var verifyButton: some View {
        Button {
            Task {
                if await auth.verifyEmailCode(code) == false {
                    code = ""
                    isCodeFieldFocused = true
                }
            }
        } label: {
            Text("確認して登録を完了")
                .bold()
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isCodeComplete ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color(.systemGray4)))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .disabled(!isCodeComplete || auth.isLoading)
    }

    private var resendButton: some View {
        Button {
            Task {
                if await auth.resendVerificationEmail() {
                    showingResentToast = true
                    startResendCountdown()
                }
            }
        } label: {
            Text(secondsUntilResend > 0 ? "コードを再送する(\(secondsUntilResend)秒後)" : "コードを再送する")
                .font(.subheadline.bold())
                .foregroundStyle(secondsUntilResend > 0 ? Color.secondary : Color.brandPurple)
        }
        .disabled(secondsUntilResend > 0 || auth.isLoading)
    }

    private var notReceivedNote: some View {
        VStack(spacing: 6) {
            Text("メールが届かない場合")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("迷惑メールフォルダをご確認ください。大学のメールは受信までに数分かかることがあります。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    /// 連打による送信制限を避けるため、再送は一定時間あけてもらう。
    private func startResendCountdown() {
        secondsUntilResend = 60
        Task {
            while secondsUntilResend > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                secondsUntilResend -= 1
            }
        }
    }
}

#Preview {
    NavigationStack {
        EmailVerificationView(email: "student@stu.hosei.ac.jp")
            .environmentObject(AuthManager())
    }
}
