//
//  TranslatedText.swift
//  Matching App
//

import SwiftUI
import Translation

extension String {
    /// ひらがな・カタカナのみで構成された名前をローマ字に変換して返す。
    /// 漢字を含む名前は、変換すると読みが中国語(ピンイン)になってしまい誤った表記に
    /// なるため(例:「佐藤」→"zuo teng")、そのまま返す。
    var romanizedIfKanaOnly: String {
        let isKanaOnly = !isEmpty && unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x3040...0x309F, // ひらがな
                 0x30A0...0x30FF, // カタカナ
                 0x0020, 0x3000, 0x30FC: // 半角/全角スペース・長音符
                return true
            default:
                return false
            }
        }
        guard isKanaOnly,
              let latin = (self as NSString).applyingTransform(.toLatin, reverse: false) else { return self }
        let stripped = (latin as NSString).applyingTransform(.stripDiacritics, reverse: false) ?? latin
        return stripped.capitalized
    }

    /// アプリの表示言語がEnglishの時だけromanizedIfKanaOnlyを適用する。
    var displayNameForCurrentLanguage: String {
        guard AppLanguage.currentLocale.language.languageCode?.identifier == "en" else { return self }
        return romanizedIfKanaOnly
    }
}

/// 他ユーザーが入力した自己紹介文・一言コメントなどを表示するための文言。
/// アプリの表示言語がEnglishのときだけ、Appleの端末内翻訳(Translationフレームワーク)で
/// その場で日本語→英語に翻訳して表示する。日本語表示中や翻訳に失敗した場合は原文のまま表示する。
/// (翻訳はネットワーク不要・端末内で完結するため、プライバシー・通信コストの心配がない)
struct TranslatedText: View {
    let originalText: String
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var translatedText: String?
    @State private var configuration: TranslationSession.Configuration?

    private var shouldTranslate: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AppLanguage.currentLocale.language.languageCode?.identifier == "en"
    }

    var body: some View {
        Text(translatedText ?? originalText)
            .translationTask(configuration) { session in
                do {
                    let response = try await session.translate(originalText)
                    translatedText = response.targetText
                } catch {
                    // 翻訳に失敗しても原文をそのまま表示し続けるため、ここでは何もしない。
                    print("translation error: \(error)")
                }
            }
            .task(id: appLanguageRaw) {
                guard shouldTranslate else {
                    configuration = nil
                    translatedText = nil
                    return
                }
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "ja"),
                    target: Locale.Language(identifier: "en")
                )
            }
    }
}
