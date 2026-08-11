//
//  ProfileManager.swift
//  Matching App
//
//  Created by Kaito Seto on 2026/07/31.
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
class ProfileManager: ObservableObject {
    @Published var profile: Profile?
    @Published var university: University?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var photos: [ProfilePhoto] = []
    var mainPhoto: ProfilePhoto? {
        return photos.first(where: {$0.isMain})
    }
    func reorder(newOrder: [ProfilePhoto]) async {
        photos = newOrder.enumerated().map { index, photo in
            var p = photo
            p.orderNumber = index
            return p
        }
        await normalizeOrderNumber()
    }
    func makeMain(photo: ProfilePhoto) async {
        var reordered = photos
        guard let index = reordered.firstIndex(where: {$0.id == photo.id}) else {return}
        let movedPhoto = reordered.remove(at: index)
        reordered.insert(movedPhoto, at: 0)
        await reorder(newOrder: reordered)
    }
    func load() async {
        guard let uid = supabase().auth.currentUser?.id else {return}
        isLoading = true
        errorMessage = nil
        do {
            profile = try await
            supabase().from("profiles").select("*").eq("id",value: uid).single().execute().value
            await loadPhotos()
            if let universityId = profile?.universityId {
                await loadUniversity(id: universityId)
            }
        } catch {
            errorMessage = "プロフィールを読み込ませんでした"
            print("profile load error: \(error)")
        }
    }
    func addPhoto(image: UIImage) async {
        guard let data = image.resized(maxDimension: 1080).jpegData(compressionQuality: 0.8) else {return }
        guard let uid = supabase().auth.currentUser?.id else {return}
        let commonId = UUID()
        let filePath = "\(uid.uuidString)/\(commonId.uuidString).jpg"
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase().storage.from("profile_photos").upload(filePath, data: data, options: FileOptions(contentType: "image/jpeg"))
            let url = try await supabase().storage.from("profile_photos").getPublicURL(path: filePath)
            let newPhoto = ProfilePhoto(id: commonId, userId: uid, urlString: url.absoluteString, orderNumber: photos.count)
            try await supabase().from("profile_photos").insert([newPhoto]).execute()
            try await loadPhotos()
        } catch {
            errorMessage = "写真の保存に失敗しました"
            print("photo upload error: \(error)")
        }
    }
    func changeMainPhoto(image: UIImage) async {
        await addPhoto(image: image)
        guard let newestPhoto = photos.max(by: { $0.orderNumber < $1.orderNumber }) else { return }
        await makeMain(photo: newestPhoto)
    }
    func updateShowLikeCount(_ show: Bool) async {
        guard let uid = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("profiles")
                .update(["show_like_count": show])
                .eq("id", value: uid)
                .execute()
            await load()
        } catch {
            errorMessage = "設定の保存に失敗しました"
            print("update show_like_count error: \(error)")
        }
    }
    func updatePrivateMode(_ isPrivate: Bool) async {
        guard let uid = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("profiles")
                .update(["private_mode": isPrivate])
                .eq("id", value: uid)
                .execute()
            await load()
        } catch {
            errorMessage = "設定の保存に失敗しました"
            print("update private_mode error: \(error)")
        }
    }
    func updateShowOnlineStatus(_ show: Bool) async {
        guard let uid = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("profiles")
                .update(["show_online_status": show])
                .eq("id", value: uid)
                .execute()
            await load()
        } catch {
            errorMessage = "設定の保存に失敗しました"
            print("update show_online_status error: \(error)")
        }
    }
    func purchaseLikesMock() async {
        do {
            try await supabase().rpc("purchase_likes_mock").execute()
            await load()
        } catch {
            errorMessage = "いいねの購入に失敗しました"
            print("purchase likes error: \(error)")
        }
    }

    /// 複数プラン(10/50/100いいね、いずれも100円=1いいね換算)から選んで購入する。
    @discardableResult
    func purchaseLikes(amount: Int) async -> Bool {
        do {
            try await supabase().rpc("purchase_likes_mock", params: ["p_amount": amount]).execute()
            await load()
            return true
        } catch {
            errorMessage = "いいねの購入に失敗しました"
            print("purchase likes error: \(error)")
            return false
        }
    }
    /// 成功したらtrueを返す(いいねが足りない場合はfalse)。
    @discardableResult
    func claimShareBonus() async -> Bool {
        do {
            try await supabase().rpc("claim_share_bonus").execute()
            await load()
            return true
        } catch {
            print("claim share bonus error: \(error)")
            return false
        }
    }

    @discardableResult
    func activateBoost() async -> Bool {
        do {
            try await supabase().rpc("activate_boost").execute()
            await load()
            return true
        } catch {
            errorMessage = "アピールの利用に失敗しました(残いいねが足りない可能性があります)"
            print("activate boost error: \(error)")
            return false
        }
    }
    func loadPhotos() async {
        do {
            guard let uid = supabase().auth.currentUser?.id else {return}
            photos = try await supabase().from("profile_photos").select().eq("user_id",value: uid).order("order_number",ascending: true).execute().value
            print(photos)
        } catch {
            print("load photos error \(error)")
        }
    }
    
    func loadUniversity(id: UUID) async {
        do {
            university = try await supabase().from("universities").select("*").eq("id",value: id).single().execute().value
        } catch {
            errorMessage = "大学情報を読み込めませんでした"
            print("university load error: \(error)")
        }
    }
    func save(name: String, description: String, gender: Gender, birthday: Date, area: String, height: Int, major: String, nationality: String, tagline: String, drinking: String, smoking: String, bodyType: String, languages: [String], replyPace: String, replyTime: String) async -> Bool{
        guard let uid = supabase().auth.currentUser?.id else { return false}
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        struct Payload: Encodable {
            let name: String
            let description: String
            let gender: Gender
            let birthday: String   // ← String に変更
            let area: String
            let height: Int
            let major: String
            let nationality: String
            let tagline: String
            let drinking: String
            let smoking: String
            let bodyType: String
            let languages: [String]
            let replyPace: String
            let replyTime: String
            enum CodingKeys: String, CodingKey {
                case name, description, gender, birthday, area, height, major, nationality, tagline, drinking, smoking, languages
                case bodyType = "body_type"
                case replyPace = "reply_pace"
                case replyTime = "reply_time"
            }
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC") // ローカルのズレを避ける
        formatter.dateFormat = "yyyy-MM-dd"

        let payload = Payload(
            name: name,
            description: description,
            gender: gender,
            birthday: formatter.string(from: birthday),
            area: area,
            height: height,
            major: major,
            nationality: nationality,
            tagline: tagline,
            drinking: drinking,
            smoking: smoking,
            bodyType: bodyType,
            languages: languages,
            replyPace: replyPace,
            replyTime: replyTime
        )

        do {
            try await supabase().from("profiles").update(payload).eq("id", value: uid).execute()
            return true
        } catch {
            errorMessage = "保存に失敗しました"
            print("save error: \(error)")
        }
        return false
    }
    func deletePhoto(photo: ProfilePhoto) async {
        do {
            try await supabase()
                .from("profile_photos")
                .delete()
                .eq("id", value: photo.id)
                .execute()
            let filePath = "\(photo.userId.uuidString)/\(photo.id.uuidString).jpg"
            try await supabase().storage.from("profile_photos").remove(paths: [filePath])
            await normalizeOrderNumber()
            await loadPhotos()
        } catch {
            print("delete error: \(error)")
        }
    }
    func normalizeOrderNumber() async {
        for (index, photo) in photos.enumerated() {
            do {
                try await supabase()
                    .from("profile_photos")
                    .update(["order_number": index])
                    .eq("id", value: photo.id)
                    .execute()
            } catch {
                print("normalize error: \(error)")
            }
        }
    }
        
    static var preview: ProfileManager {
        let manager = ProfileManager()
        let uid = UUID()
        manager.profile = Profile(id: uid, universityId: UUID(), name: "sample", description: "sample", gender: .male, birthday: Date(), profileImageUrlString: nil, area: "sample", height: 165, major: "情報科学", nationality: "日本", tagline: "よろしくお願いします!", showLikeCount: true, remainingLikes: 100, privateMode: false, showOnlineStatus: true, shareBonusClaimed: false, isAdmin: false, drinking: "時々飲む", smoking: "吸わない", bodyType: "普通", languages: ["日本語", "英語"], replyPace: "すぐ返す", replyTime: "夜型", boostExpiresAtString: nil, createdAtString: nil)
        manager.university = University(id: UUID(), name: "サンプル大学", domain: "example.ac.jp", country: "日本")

            manager.photos = [
              ProfilePhoto(id: UUID(), userId: uid, urlString: "https://picsum.photos/seed/1/400", orderNumber: 1),
              ProfilePhoto(id: UUID(), userId: uid, urlString: "https://picsum.photos/seed/2/400", orderNumber: 2),
              ProfilePhoto(id: UUID(), userId: uid, urlString: "https://picsum.photos/seed/3/400", orderNumber: 3),
            ]

            return manager
        
    }
    
}
