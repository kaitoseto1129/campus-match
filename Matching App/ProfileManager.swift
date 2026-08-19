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
    /// 写真をドラッグ&ドロップした時に、2つのスロットの表示位置(order_number)だけを入れ替える。
    func swapPhotos(at slotA: Int, and slotB: Int) async {
        guard slotA != slotB, let photoA = photos.first(where: { $0.orderNumber == slotA }) else { return }
        let photoB = photos.first(where: { $0.orderNumber == slotB })
        do {
            try await supabase().from("profile_photos").update(["order_number": -1]).eq("id", value: photoA.id).execute()
            if let photoB {
                try await supabase().from("profile_photos").update(["order_number": slotA]).eq("id", value: photoB.id).execute()
            }
            try await supabase().from("profile_photos").update(["order_number": slotB]).eq("id", value: photoA.id).execute()
            await loadPhotos()
        } catch {
            print("swap photos error: \(error)")
        }
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
        await addPhoto(image: image, atSlot: photos.count)
    }

    /// 指定したスロット(0=メイン, 1〜3=サブ)に直接写真を登録する。
    /// メインが空でもサブから先に埋められるように、常に「次の空き」ではなく指定スロットへ入れる。
    func addPhoto(image: UIImage, atSlot slot: Int) async {
        guard let data = image.resized(maxDimension: 1080).jpegData(compressionQuality: 0.8) else {return }
        guard let uid = supabase().auth.currentUser?.id else {return}
        let commonId = UUID()
        let filePath = "\(uid.uuidString)/\(commonId.uuidString).jpg"
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase().storage.from("profile_photos").upload(filePath, data: data, options: FileOptions(contentType: "image/jpeg"))
            let url = try await supabase().storage.from("profile_photos").getPublicURL(path: filePath)
            let newPhoto = ProfilePhoto(id: commonId, userId: uid, urlString: url.absoluteString, orderNumber: slot)
            try await supabase().from("profile_photos").insert([newPhoto]).execute()
            // 保存自体は成功しているのに再取得が何らかの理由で失敗すると
            // 画面に反映されない(反映されていないように見える)ため、ローカルにも即時反映しておく。
            photos.removeAll { $0.orderNumber == slot }
            photos.append(newPhoto)
            await loadPhotos()
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

    /// 選択した趣味カードを保存する。
    @discardableResult
    func saveHobbyCards(_ cards: [String]) async -> Bool {
        guard let uid = supabase().auth.currentUser?.id else { return false }
        do {
            try await supabase()
                .from("profiles")
                .update(["hobby_cards": cards])
                .eq("id", value: uid)
                .execute()
            await load()
            return true
        } catch {
            errorMessage = "趣味カードの保存に失敗しました"
            print("save hobby cards error: \(error)")
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

    /// アピールを時間経過を待たずに終了する。消費したいいねは返却されない
    /// (時間より前に自分の意志で切り上げるだけの操作なので)。
    @discardableResult
    func cancelBoost() async -> Bool {
        guard let uid = supabase().auth.currentUser?.id else { return false }
        do {
            try await supabase()
                .from("profiles")
                .update(["boost_expires_at": ISO8601DateFormatter.matchingApp.string(from: Date())])
                .eq("id", value: uid)
                .execute()
            await load()
            return true
        } catch {
            errorMessage = "アピールの終了に失敗しました"
            print("cancel boost error: \(error)")
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
    func save(name: String, description: String, gender: Gender, birthday: Date, area: String, city: String?, height: Int?, major: String, nationalities: [String], tagline: String, drinking: String, smoking: String, bodyType: String, languages: [String], universityId: UUID) async -> Bool{
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
            let city: String?
            /// 身長は必須ではなくなったため、未設定(nil)を許容する。
            let height: Int?
            let major: String
            let nationality: String
            let nationalities: [String]
            let tagline: String
            let drinking: String
            let smoking: String
            let bodyType: String
            let languages: [String]
            let universityId: UUID
            enum CodingKeys: String, CodingKey {
                case name, description, gender, birthday, area, city, height, major, nationality, nationalities, tagline, drinking, smoking, languages
                case bodyType = "body_type"
                case universityId = "university_id"
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
            city: city,
            height: height,
            major: major,
            // 旧・単一nationality列は表示フォールバック用に、複数選択の先頭値だけ入れておく。
            nationality: nationalities.first ?? "",
            nationalities: nationalities,
            tagline: tagline,
            drinking: drinking,
            smoking: smoking,
            bodyType: bodyType,
            languages: languages,
            universityId: universityId
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
    /// 指定スロットの写真だけを削除する。スロット番号(0=メイン、1〜=サブ)はドラッグ順ではなく
    /// 「その枠の意味」を表す固定値なので、削除しても他のスロットの番号は詰めない
    /// (以前はここでnormalizeOrderNumber()を呼んでいたため、例えばサブ写真を削除すると
    /// 別のサブ写真のorder_numberが繰り上がって、削除直後に同じスロットへ再登録しようとした際に
    /// order_numberの一意制約に衝突し「写真を追加できません」と表示されるバグの原因になっていた)。
    @discardableResult
    func deletePhoto(photo: ProfilePhoto) async -> Bool {
        do {
            try await supabase()
                .from("profile_photos")
                .delete()
                .eq("id", value: photo.id)
                .execute()
            let filePath = "\(photo.userId.uuidString)/\(photo.id.uuidString).jpg"
            try await supabase().storage.from("profile_photos").remove(paths: [filePath])
            await loadPhotos()
            return true
        } catch {
            errorMessage = "写真の削除に失敗しました"
            print("delete error: \(error)")
            return false
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
        manager.profile = Profile(id: uid, universityId: UUID(), name: "sample", description: "sample", gender: .male, birthday: Date(), profileImageUrlString: nil, area: "sample", city: nil, height: 165, major: "情報科学", nationality: "日本", nationalities: ["日本"], tagline: "よろしくお願いします!", showLikeCount: true, remainingLikes: 100, privateMode: false, showOnlineStatus: true, shareBonusClaimed: false, isAdmin: false, drinking: "時々飲む", smoking: "吸わない", bodyType: "普通", languages: ["日本語", "英語"], membershipTier: .free, hobbyCards: ["movie", "cafe", "music"], boostExpiresAtString: nil, createdAtString: nil)
        manager.university = University(id: UUID(), name: "サンプル大学", domain: "example.ac.jp", country: "日本", prefecture: "東京都")

            manager.photos = [
              ProfilePhoto(id: UUID(), userId: uid, urlString: "https://picsum.photos/seed/1/400", orderNumber: 1),
              ProfilePhoto(id: UUID(), userId: uid, urlString: "https://picsum.photos/seed/2/400", orderNumber: 2),
              ProfilePhoto(id: UUID(), userId: uid, urlString: "https://picsum.photos/seed/3/400", orderNumber: 3),
            ]

            return manager
        
    }
    
}
