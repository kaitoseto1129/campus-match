//
//  ContactView.swift
//  Matching App
//

import SwiftUI
import UIKit

/// お問い合わせ画面。
///
/// 以前は mailto: リンクを直接開いていたが、メールアプリが設定されていない端末や
/// シミュレーターでは何も起きず「タップしても反応しない」状態になっていた。
/// ここではアドレスを画面に明示したうえで、メールアプリを開く導線とコピー手段の両方を用意し、
/// どの環境でも必ず連絡先が分かるようにしている。
struct ContactView: View {
    @State private var showingCopiedToast = false
    @State private var showingNoMailAppAlert = false

    private var address: String { LegalDocument.contactEmail }

    var body: some View {
        ZStack {
            Color.appListBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    addressCard
                    topicsCard
                    Spacer(minLength: 0)
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .alert("メールアプリを開けませんでした", isPresented: $showingNoMailAppAlert) {
            Button("アドレスをコピー") { copyAddress() }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("お使いの端末でメールアプリが設定されていないようです。\(address) 宛にご連絡ください。")
        }
        .sentConfirmationCover(isPresented: $showingCopiedToast, message: "アドレスをコピーしました", icon: "doc.on.doc.fill")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white)
                .padding(22)
                .background(Color.brandGradient, in: Circle())
            Text("ご意見・ご相談をお寄せください")
                .font(.subheadline.bold())
            Text("いただいたお問い合わせには、運営者が順次対応いたします。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var addressCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("お問い合わせ先")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(address)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brandPurple)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
            }

            Button {
                openMailApp()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("メールアプリで作成する")
                        .bold()
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.brandGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            Button {
                copyAddress()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("アドレスをコピー")
                        .bold()
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.brandPurple.opacity(0.12))
                .foregroundStyle(Color.brandPurple)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var topicsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("こんなときにご連絡ください")
                .font(.subheadline.bold())
            topicRow(icon: "exclamationmark.triangle.fill", color: Color.brandOrange, text: "迷惑行為・不適切な利用者を見かけたとき")
            topicRow(icon: "ladybug.fill", color: .red, text: "アプリの不具合を見つけたとき")
            topicRow(icon: "creditcard.fill", color: Color.brandTeal, text: "購入・有料会員についてのご相談")
            topicRow(icon: "lock.fill", color: Color(.systemGray), text: "個人情報の開示・訂正・削除のご請求")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func topicRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.footnote)
            Spacer()
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = address
        showingCopiedToast = true
    }

    private func openMailApp() {
        let subject = "キャンパスマッチ お問い合わせ"
        var components = URLComponents(string: "mailto:\(address)")
        components?.queryItems = [URLQueryItem(name: "subject", value: subject)]
        guard let url = components?.url, UIApplication.shared.canOpenURL(url) else {
            showingNoMailAppAlert = true
            return
        }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        ContactView()
    }
}
