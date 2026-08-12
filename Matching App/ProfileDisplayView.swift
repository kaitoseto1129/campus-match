//
//  ProfileDisplayView.swift
//  Matching App
//

import SwiftUI
import UIKit

struct ProfileDisplayView<ActionContent: View>: View {
    let profile: Profile?
    let university: University?
    let photos: [ProfilePhoto]
    var showsPhotoEditHint: Bool = false
    var likeCount: Int? = nil
    var isOnline: Bool? = nil
    var otherProfiles: [Profile] = []
    var otherProfilePhotoURLs: [UUID: URL] = [:]
    var onTapMainPhoto: (() -> Void)? = nil
    /// 閲覧トラッキング用: セクションが画面に現れた時に呼ばれる(自分のプロフィール表示時はnilのまま)。
    var onSectionAppear: ((ProfileSection) -> Void)? = nil
    /// 閲覧トラッキング用: 写真が画面に現れた時に呼ばれる。
    var onPhotoAppear: ((UUID) -> Void)? = nil
    @ViewBuilder var actionContent: () -> ActionContent
    @State private var zoomedPhotoURL: URL?

    var mainPhoto: ProfilePhoto? {
        photos.first(where: { $0.isMain })
    }

    /// プロフィールIDから決まる、一貫したランダムなパステルカラー。
    private var backgroundTint: Color {
        guard let id = profile?.id else { return Color(.systemGray6) }
        var hasher = Hasher()
        hasher.combine(id)
        let hue = Double(abs(hasher.finalize()) % 360) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.96)
    }

    var header: some View {
        ZStack(alignment: .bottomTrailing) {
            SquarePhotoView(url: mainPhoto?.url)
                .onTapGesture {
                    if let url = mainPhoto?.url {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { zoomedPhotoURL = url }
                    }
                }
                .onAppear {
                    onSectionAppear?(.header)
                    if let id = mainPhoto?.id { onPhotoAppear?(id) }
                }
            if showsPhotoEditHint {
                Button {
                    onTapMainPhoto?()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .padding(14)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    var taglineSection: some View {
        Group {
            if let tagline = profile?.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .onAppear { onSectionAppear?(.tagline) }
            }
        }
    }

    var subPhotosSection: some View {
        Group {
            let subPhotos = photos.filter { !$0.isMain }
            if !subPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(subPhotos) { photo in
                            SquarePhotoView(url: photo.url, cornerRadius: 12)
                                .frame(width: 130, height: 130)
                                .onTapGesture {
                                    if let url = photo.url {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { zoomedPhotoURL = url }
                                    }
                                }
                                .onAppear { onPhotoAppear?(photo.id) }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .onAppear { onSectionAppear?(.subPhotos) }
            }
        }
    }

    var nameAgeAreaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(profile?.name ?? "-")
                    .font(.title2.bold())
                Text(profile?.ageLabel ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(profile?.area ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let likeCount {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                        Text(likeCount <= 5 ? "〜5" : "\(likeCount)")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.brandPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandPurple.opacity(0.12), in: Capsule())
                }
            }
            if let isOnline {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isOnline ? Color.green : Color(.systemGray3))
                        .frame(width: 8, height: 8)
                    Text(isOnline ? "オンライン" : "オフライン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .onAppear { onSectionAppear?(.nameAgeArea) }
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自己紹介文")
                .font(Font.title3.bold())
            Text(profile?.description ?? "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .onAppear { onSectionAppear?(.about) }
    }

    var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("基本情報")
                .font(.title3.bold())
                .padding(.bottom, 8)
            infoRow(label: "ニックネーム", value: profile?.name ?? "-")
            Divider()
            infoRow(label: "年齢", value: profile?.ageLabel ?? "-")
            Divider()
            infoRow(label: "身長", value: profile?.heightLabel ?? "-")
            Divider()
            infoRow(label: "専攻", value: profile?.major ?? "-")
            Divider()
            infoRow(label: "居住地", value: profile?.area ?? "-")
            Divider()
            infoRow(label: "国籍", value: (profile?.nationalities.isEmpty ?? true) ? "-" : (profile?.nationalities.joined(separator: "・") ?? "-"))
            Divider()
            infoRow(label: "性別", value: profile?.gender?.label ?? "-")
            Divider()
            infoRow(label: "大学", value: university?.name ?? "-")
            Divider()
            infoRow(label: "お酒", value: profile?.drinking ?? "-")
            Divider()
            infoRow(label: "タバコ", value: profile?.smoking ?? "-")
            Divider()
            infoRow(label: "体型", value: profile?.bodyType ?? "-")
            Divider()
            infoRow(label: "話せる言語", value: (profile?.languages.isEmpty ?? true) ? "-" : (profile?.languages.joined(separator: "・") ?? "-"))

        }
        .padding(.horizontal)
        .onAppear { onSectionAppear?(.basicInfo) }
    }
    var otherProfilesSection: some View {
        Group {
            if !otherProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("他のユーザーも見てみる")
                        .font(.title3.bold())
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(otherProfiles.enumerated()), id: \.element.id) { index, other in
                            NavigationLink {
                                SwipeableProfileView(profiles: otherProfiles, startIndex: index) { p in
                                    QuickLikeButton(profile: p, photoURL: otherProfilePhotoURLs[p.id])
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    SquarePhotoView(url: otherProfilePhotoURLs[other.id], cornerRadius: 10)
                                    Text(other.ageLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .onAppear { onSectionAppear?(.otherProfiles) }
            }
        }
    }

    func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.brandPurple)
        }
        .padding(.vertical, 14)
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                backgroundTint.opacity(0.28).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        header
                        taglineSection
                        subPhotosSection
                        nameAgeAreaSection
                        aboutSection
                        basicInfoSection
                        otherProfilesSection
                        Color.clear.frame(height: 20)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionContent()
                    .padding(.top, 10)
                    .background(
                        Color(.systemBackground)
                            .shadow(color: .black.opacity(0.16), radius: 14, y: -6)
                    )
            }

            if let zoomedPhotoURL {
                // 背景はそのまま(暗転させない)、写真だけがその場でぶわんと拡大される。
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { self.zoomedPhotoURL = nil }
                    }
                AsyncImage(url: zoomedPhotoURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { self.zoomedPhotoURL = nil }
                            }
                    }
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }
}

private struct SquarePhotoView: View {
    let url: URL?
    var cornerRadius: CGFloat = 20

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray6)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color(.systemGray3))
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .clipped()
    }
}
