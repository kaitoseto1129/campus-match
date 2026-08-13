//
//  MatchCelebrationView.swift
//  Matching App
//

import SwiftUI

struct MatchCelebrationView: View {
    let myPhotoURL: URL?
    let myName: String
    let otherProfile: Profile
    let otherPhotoURL: URL?
    let matchId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var showsChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.99, green: 0.68, blue: 0.66), Color.brandPurple],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 90)

                    Text("マッチングが成立しました!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    ZStack {
                        HStack(spacing: 20) {
                            photoCircle(url: myPhotoURL)
                            photoCircle(url: otherPhotoURL)
                        }
                        Image(systemName: "heart.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.9), radius: 14)
                    }
                    .padding(.top, 40)

                    HStack(spacing: 44) {
                        Text(myName)
                        Text(otherProfile.name)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 10)

                    Spacer()

                    hintRow
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    Button {
                        showsChat = true
                    } label: {
                        Text("メッセージを送る")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.white)
                            .foregroundStyle(Color.brandPurple)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)

                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationDestination(isPresented: $showsChat) {
                ChatView(matchId: matchId, otherProfile: otherProfile, otherPhotoURL: otherPhotoURL)
            }
        }
        .onChange(of: showsChat) { wasShowing, isShowing in
            // チャットへ遷移したあと、戻るボタンでこの成立画面に戻ってきたら
            // マッチ成立演出自体を閉じる(もう一度見せる必要はないため)。
            if wasShowing && !isShowing {
                dismiss()
            }
        }
    }

    private var hintRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(Color.brandPurple)
                .padding(10)
                .background(.white, in: Circle())
            Text("60分以内に最初のメッセージを送るとトークが長続きする傾向にあります")
                .font(.caption)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func photoCircle(url: URL?) -> some View {
        IconImage(url: url, size: 130)
            .overlay(Circle().stroke(.white, lineWidth: 4))
    }
}

#Preview {
    MatchCelebrationView(
        myPhotoURL: nil,
        myName: "自分",
        otherProfile: ProfileManager.preview.profile!,
        otherPhotoURL: nil,
        matchId: UUID()
    )
}
