//
//  PopularMemberSheet.swift
//  Matching App
//

import SwiftUI

struct PopularMemberSheet: View {
    let profile: Profile
    let photoURL: URL?
    let onConfirm: (Bool) -> Void

    @State private var useSpecial = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            IconImage(url: photoURL, size: 100)

            Text("このお相手は人気会員です")
                .font(.title3.bold())
                .foregroundStyle(Color.brandOrange)

            Text("見逃されないようにスペシャルいいね!を使いましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Toggle(isOn: $useSpecial) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("スペシャルいいね!で優先表示")
                        .font(.subheadline.bold())
                    Text("追加で1いいねを消費します(合計2いいね)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.brandPurple)
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            Button {
                onConfirm(useSpecial)
            } label: {
                HStack {
                    Image(systemName: "hand.thumbsup.fill")
                    Text("いいね!")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.brandPurple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 24)
        .presentationDetents([.medium])
    }
}

#Preview {
    PopularMemberSheet(profile: ProfileManager.preview.profile!, photoURL: nil) { _ in }
}
