//
//  MembershipLookup.swift
//  Matching App
//

import Foundation
import Supabase

/// 自分の会員ステータスだけを軽く引くためのヘルパー。
/// ProfileManagerを丸ごと持ちたくない画面(トーク画面や相手プロフィールなど)から使う。
enum MembershipLookup {
    private struct Row: Decodable {
        let membershipTier: MembershipTier?
        enum CodingKeys: String, CodingKey {
            case membershipTier = "membership_tier"
        }
    }

    static func myTier() async -> MembershipTier {
        guard let uid = supabase().auth.currentUser?.id else { return .free }
        do {
            let row: Row = try await supabase()
                .from("profiles")
                .select("membership_tier")
                .eq("id", value: uid)
                .single()
                .execute()
                .value
            return row.membershipTier ?? .free
        } catch {
            print("membership lookup error: \(error)")
            return .free
        }
    }
}
