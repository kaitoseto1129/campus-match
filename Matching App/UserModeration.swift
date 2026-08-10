//
//  UserModeration.swift
//  Matching App
//

import Foundation
import Supabase

enum UserModeration {
    private struct TargetRow: Decodable {
        let targetId: UUID
        enum CodingKeys: String, CodingKey {
            case targetId = "target_id"
        }
    }

    private struct ActionPayload: Encodable {
        let actorId: UUID
        let targetId: UUID
        let action: String
        enum CodingKeys: String, CodingKey {
            case actorId = "actor_id"
            case targetId = "target_id"
            case action
        }
    }

    private struct ReportPayload: Encodable {
        let reporterId: UUID
        let reportedId: UUID
        let reason: String
        enum CodingKeys: String, CodingKey {
            case reporterId = "reporter_id"
            case reportedId = "reported_id"
            case reason
        }
    }

    /// 自分が「非表示」または「ブロック」した相手のID一覧。
    static func hiddenOrBlockedIds(actorId: UUID) async -> Set<UUID> {
        do {
            let rows: [TargetRow] = try await supabase()
                .from("user_actions")
                .select("target_id")
                .eq("actor_id", value: actorId)
                .execute()
                .value
            return Set(rows.map(\.targetId))
        } catch {
            print("user moderation fetch error: \(error)")
            return []
        }
    }

    /// 自分と相手のどちらかがもう一方をブロックしているか(双方向)。
    static func isBlocked(between myId: UUID, and otherId: UUID) async -> Bool {
        do {
            let rows: [TargetRow] = try await supabase()
                .from("user_actions")
                .select("target_id")
                .eq("action", value: "block")
                .or("and(actor_id.eq.\(myId),target_id.eq.\(otherId)),and(actor_id.eq.\(otherId),target_id.eq.\(myId))")
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            print("user moderation block check error: \(error)")
            return false
        }
    }

    static func hide(userId: UUID) async {
        await recordAction(userId: userId, action: "hide")
    }

    static func block(userId: UUID) async {
        await recordAction(userId: userId, action: "block")
    }

    static func report(userId: UUID, reason: String) async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("reports")
                .insert(ReportPayload(reporterId: myId, reportedId: userId, reason: reason))
                .execute()
        } catch {
            print("report error: \(error)")
        }
    }

    /// 自分がactionした(非表示/ブロックした)相手の一覧を取得する。
    static func actedUserIds(actorId: UUID, action: String) async -> [UUID] {
        do {
            let rows: [TargetRow] = try await supabase()
                .from("user_actions")
                .select("target_id")
                .eq("actor_id", value: actorId)
                .eq("action", value: action)
                .execute()
                .value
            return rows.map(\.targetId)
        } catch {
            print("user moderation acted list error: \(error)")
            return []
        }
    }

    /// 非表示/ブロックを解除する。
    static func removeAction(userId: UUID, action: String) async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("user_actions")
                .delete()
                .eq("actor_id", value: myId)
                .eq("target_id", value: userId)
                .eq("action", value: action)
                .execute()
        } catch {
            print("user moderation remove action error: \(error)")
        }
    }

    private static func recordAction(userId: UUID, action: String) async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("user_actions")
                .upsert(
                    ActionPayload(actorId: myId, targetId: userId, action: action),
                    onConflict: "actor_id,target_id,action"
                )
                .execute()
        } catch {
            print("user action error: \(error)")
        }
    }
}
