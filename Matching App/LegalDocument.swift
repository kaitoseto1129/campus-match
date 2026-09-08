//
//  LegalDocument.swift
//  Matching App
//

import SwiftUI

/// 利用規約・プライバシーポリシーの本文。
///
/// 以前は外部URL(GitHub Pages)を開く実装だったが、公開設定が済むまで404になってしまい、
/// アプリから規約が読めない状態だった。審査でも実際に開かれる箇所なので、
/// 外部の公開状況に左右されないよう本文をアプリに内蔵して表示する。
struct LegalDocument {
    let title: String
    let updatedAt: String
    let sections: [Section]

    struct Section: Identifiable {
        let id = UUID()
        let heading: String
        let body: String
    }

    static let contactEmail = "kaitoseto1129@gmail.com"

    static let termsJA = LegalDocument(
        title: "利用規約",
        updatedAt: "2026年9月8日",
        sections: [
            Section(heading: "はじめに", body: """
本規約は、大学生限定の集まり募集アプリ「キャンマッチ」(以下「本アプリ」)の利用条件を定めるものです。本アプリに登録された時点で、本規約に同意したものとみなします。
お問い合わせ窓口: \(contactEmail)
"""),
            Section(heading: "第1条(本アプリの性質)", body: """
1. 本アプリは、同じ大学に在学する学生同士が、食事・勉強・スポーツ・イベント参加などの少人数の集まりを募集し、参加者同士でグループトークを行うためのサービスです。
2. 本アプリは、異性交際(恋愛・デートを目的とした交際)の相手を紹介するサービスではありません。異性交際を目的とした利用は、第4条のとおり禁止しています。
3. 本アプリでは、利用者の性別を他の利用者に表示せず、性別を条件として相手を検索・絞り込みする機能も提供していません。
4. 本アプリには、利用者同士が1対1で個別に連絡を取り合う機能はありません。連絡は、主催者が参加を承認した集まりごとのグループトークに限られます。
"""),
            Section(heading: "第2条(利用資格)", body: """
1. 本アプリは、18歳以上かつ大学等の高等教育機関に在学中の方のみご利用いただけます。
2. 登録には、在学する大学が発行するメールアドレスが必要です。登録時にそのアドレス宛に確認コードを送り、在学確認を行います。
3. アカウントは1人につき1つとし、他人へ譲渡・貸与することはできません。
4. 過去に本規約違反により利用停止となった方は、再登録することができません。
"""),
            Section(heading: "第3条(アカウントの管理)", body: """
1. 利用者は、自己の責任でメールアドレスおよびパスワードを管理するものとします。
2. 登録情報は正確かつ最新の内容を登録するものとし、虚偽の情報を登録してはなりません。
3. アカウントの不正利用に気づいた場合は、直ちに運営者へご連絡ください。
"""),
            Section(heading: "第4条(禁止事項)", body: """
利用者は、本アプリの利用にあたり、以下の行為を行ってはなりません。

・異性交際(恋愛・デートを目的とした交際)の相手を求める目的での利用、およびその旨を示す集まりの募集・プロフィール・メッセージの投稿
・交際相手、恋人、デートの相手を募集・勧誘する行為
・法令または公序良俗に違反する行為
・他人になりすます行為、本人以外の写真を登録する行為
・年齢、在学状況その他の登録情報を偽る行為
・他の利用者に対する誹謗中傷、脅迫、差別的な言動、ハラスメント
・わいせつな内容、暴力的な内容、その他他人に不快感を与える内容の投稿・送信
・売春、援助交際、その他金銭を目的とした交際の勧誘
・宗教活動、政治活動、ネットワークビジネス、投資その他の勧誘・営業行為
・他の利用者の個人情報を、本人の同意なく第三者に開示・公開する行為
・本アプリの運営を妨害する行為、不正アクセス、リバースエンジニアリング
・複数のアカウントを作成する行為、自動化ツールを用いた操作
・その他、運営者が不適切と判断する行為
"""),
            Section(heading: "第5条(通報・違反への対応)", body: """
1. 本アプリには、他の利用者を通報・ブロック・非表示にする機能が用意されています。不適切な利用者を見つけた場合はご利用ください。
2. 通報した相手は、以後あなたの画面に表示されなくなります。
3. 運営者は、集まりの募集内容およびグループトークの内容について、第4条の禁止事項に違反する投稿がないかを継続的に確認します。
4. 運営者は、本規約への違反が疑われる場合、事前の通知なく、投稿内容の削除、機能の制限、アカウントの一時停止または削除を行うことがあります。
"""),
            Section(heading: "第6条(知的財産権)", body: """
1. 本アプリに関する著作権その他の知的財産権は、運営者または正当な権利者に帰属します。
2. 利用者が投稿した文章・写真等の権利は利用者に帰属します。ただし運営者は、本アプリの提供に必要な範囲でこれらを利用できるものとします。
3. 利用者は、自らが権利を有する、または適法に利用できる内容のみを投稿するものとします。
"""),
            Section(heading: "第7条(利用者間のトラブル)", body: """
本アプリは集まりを募集・参加するための場を提供するものであり、利用者間で生じたトラブルについて運営者は責任を負いません。実際にお会いになる際は、人目のある場所を選ぶなど、ご自身の安全に十分ご配慮ください。
"""),
            Section(heading: "第8条(免責事項)", body: """
1. 運営者は、本アプリの内容の正確性、有用性、特定目的への適合性を保証しません。
2. 運営者は、システムの保守、障害、通信回線の不具合等により、事前の通知なくサービスを中断・変更・終了することがあります。
3. 運営者の故意または重過失による場合を除き、本アプリの利用により利用者に生じた損害について責任を負いません。
"""),
            Section(heading: "第9条(退会)", body: """
利用者は、アプリ内の「マイページ」→「退会する」から、いつでもアカウントを削除できます。退会すると、プロフィール、写真、参加した集まり、グループトークの履歴などのデータは削除され、元に戻せません。
"""),
            Section(heading: "第10条(規約の変更)", body: """
運営者は、必要と判断した場合、本規約を変更することがあります。重要な変更を行う場合は、アプリ内でお知らせします。
"""),
            Section(heading: "第11条(準拠法・管轄)", body: """
本規約は日本法に準拠します。本アプリに関して紛争が生じた場合、運営者の所在地を管轄する裁判所を第一審の専属的合意管轄裁判所とします。
""")
        ]
    )

    static let privacyJA = LegalDocument(
        title: "プライバシーポリシー",
        updatedAt: "2026年9月8日",
        sections: [
            Section(heading: "はじめに", body: """
本プライバシーポリシーは、大学生限定の集まり募集アプリ「キャンマッチ」(以下「本アプリ」)における利用者情報の取扱いについて定めるものです。
お問い合わせ窓口: \(contactEmail)
"""),
            Section(heading: "1. 取得する情報", body: """
【ご登録いただく情報】
・アカウント情報: 大学が発行するメールアドレス、パスワード(ハッシュ化して保管)
・プロフィール情報: 氏名、生年月日、居住地、大学、専攻、身長、国籍、話せる言語、体型、飲酒・喫煙、自己紹介文、一言コメント、趣味カード
・写真: プロフィール写真
・集まりの情報: 主催した集まりの内容、応募内容、グループトークのメッセージ本文

【自動的に記録される情報】
・行動履歴: 最終利用日時
・安全管理情報: 非表示・ブロックの設定、通報内容

本アプリは、広告配信・トラッキング目的の識別子(IDFA)を取得せず、第三者への情報販売も行いません。位置情報も取得しません。居住地は利用者ご自身に選択いただいた地域のみを扱います。
"""),
            Section(heading: "2. 情報の利用目的", body: """
1. 本アプリの提供・維持・改善のため
2. 大学のメールアドレスによる在学確認および本人確認のため
3. 集まりの募集・応募・グループトークの提供のため
4. 規約違反、なりすまし、その他不正行為の検知・調査・対応のため
5. お問い合わせへの対応のため
6. 法令に基づく対応のため
"""),
            Section(heading: "3. 第三者提供・業務委託", body: """
運営者は、次の場合を除き、利用者の個人情報を第三者に提供しません。
・利用者ご本人の同意がある場合
・法令に基づく場合、または人の生命・身体・財産の保護のために必要な場合
・裁判所、警察等の公的機関から適法な開示要請を受けた場合

また、本アプリの提供のために以下の外部サービスを利用しています。
・Supabase, Inc.(認証・データベース・画像保管)
・Apple Inc.(App Store)

これらのサービスのサーバーは日本国外に所在する場合があります。
"""),
            Section(heading: "4. 他の利用者に公開される情報", body: """
以下の情報は、本アプリの性質上、他の利用者に公開されます。公開されたくない情報は登録しないでください。

・氏名、年齢、居住地、大学、専攻、身長、国籍、話せる言語、体型、飲酒・喫煙
・自己紹介文、一言コメント、趣味カード
・プロフィール写真
・オンライン状態(設定でオフにできます)

メールアドレス、生年月日そのもの(表示されるのは年齢のみ)、パスワードが他の利用者に公開されることはありません。性別は他の利用者に公開されず、性別による検索・絞り込みも行いません。
"""),
            Section(heading: "5. 利用者による設定・権利", body: """
・プロフィールの修正: 「マイページ」からいつでも変更できます。
・公開範囲の調整: オンライン状態の表示はオフにできます。
・退会(アカウントの削除): 「マイページ」→「退会する」からいつでもご自身で削除できます。
・開示・訂正・利用停止の請求: お問い合わせ窓口までご連絡ください。ご本人であることを確認のうえ、法令に従って対応します。
"""),
            Section(heading: "6. 保存期間", body: """
利用者情報は、アカウントが存在する間保存します。退会後は速やかに削除しますが、法令に基づく保存義務がある情報、および規約違反への対応・再登録防止のために必要な最小限の記録は、必要な範囲・期間に限り保持することがあります。
"""),
            Section(heading: "7. 安全管理措置", body: """
・通信はすべてTLSにより暗号化しています。
・パスワードはハッシュ化して保管し、運営者も平文を知ることはできません。
・データベースには行単位のアクセス制御(RLS)を設定し、参加していない集まりのグループトークなどに権限なくアクセスできないようにしています。
"""),
            Section(heading: "8. 未成年者の利用について", body: """
本アプリは18歳以上かつ大学等に在学中の方のみご利用いただけます。18歳未満の方の登録・利用は固くお断りします。
"""),
            Section(heading: "9. 本ポリシーの変更", body: """
法令の変更や機能の追加に応じて本ポリシーを改定することがあります。重要な変更を行う場合は、アプリ内でお知らせします。
""")
        ]
    )

    static let termsEN = LegalDocument(
        title: "Terms of Service",
        updatedAt: "September 8, 2026",
        sections: [
            Section(heading: "Introduction", body: """
These Terms of Service ("Terms") govern the use of CamMatch (the "App"), a group-meetup app exclusively for university students. By registering for the App, you are deemed to have agreed to these Terms.
Contact: \(contactEmail)
"""),
            Section(heading: "Article 1 (Nature of the App)", body: """
1. The App is a service that lets students enrolled at the same university post and join small group meetups — meals, study sessions, sports, events and the like — and talk with the other participants in a group chat.
2. The App is not a service for introducing partners for romantic or dating relationships. Using it for that purpose is prohibited under Article 4.
3. The App does not show a user's gender to other users, and provides no feature for searching or filtering other users by gender.
4. The App has no one-to-one private messaging between users. Communication is limited to the group chat of a meetup whose host has approved your application.
"""),
            Section(heading: "Article 2 (Eligibility)", body: """
1. The App is available only to users who are 18 years of age or older and currently enrolled at a university or other institution of higher education.
2. Registration requires an email address issued by your university. We will send a verification code to that address at sign-up to confirm your enrollment.
3. Each person may hold only one account, which may not be transferred or lent to another person.
4. Users previously suspended for violating these Terms may not re-register.
"""),
            Section(heading: "Article 3 (Account Management)", body: """
1. You are responsible for managing your own email address and password.
2. You must register accurate and up-to-date information and must not register false information.
3. If you notice any unauthorized use of your account, please contact the operator immediately.
"""),
            Section(heading: "Article 4 (Prohibited Conduct)", body: """
When using the App, you must not engage in any of the following:

・Using the App to look for a romantic or dating partner, or posting meetups, profiles or messages indicating such a purpose
・Soliciting or recruiting a partner, boyfriend, girlfriend or date
・Acts that violate any law or public order and morals
・Impersonating another person, or registering photos of someone other than yourself
・Falsifying your age, enrollment status or other registration details
・Defamation, threats, discriminatory remarks or harassment toward other users
・Posting or sending obscene or violent content, or other content that causes discomfort to others
・Soliciting prostitution, compensated dating, or any other relationship for monetary gain
・Religious or political activity, multi-level marketing, investment solicitation or other commercial solicitation
・Disclosing another user's personal information to third parties without their consent
・Interfering with the operation of the App, unauthorized access, or reverse engineering
・Creating multiple accounts, or operating the App with automated tools
・Any other conduct the operator deems inappropriate
"""),
            Section(heading: "Article 5 (Reports and Handling of Violations)", body: """
1. The App provides features to report, block and hide other users. Please use them if you encounter an inappropriate user.
2. A user you report will no longer appear on your screen.
3. The operator continuously reviews meetup postings and group chat content for posts that violate the prohibitions in Article 4.
4. If a violation of these Terms is suspected, the operator may, without prior notice, delete content, restrict features, or suspend or delete the account.
"""),
            Section(heading: "Article 6 (Intellectual Property)", body: """
1. Copyright and other intellectual property rights relating to the App belong to the operator or other rightful owners.
2. Rights to text, photos and other content you post belong to you. However, the operator may use such content to the extent necessary to provide the App.
3. You may post only content that you own or are otherwise lawfully entitled to use.
"""),
            Section(heading: "Article 7 (Disputes Between Users)", body: """
The App provides a place to post and join group meetups; the operator is not responsible for disputes that arise between users. When meeting in person, please take care of your own safety — for example, by choosing a public place.
"""),
            Section(heading: "Article 8 (Disclaimer)", body: """
1. The operator does not warrant the accuracy, usefulness or fitness for a particular purpose of the App's content.
2. The operator may suspend, change or terminate the service without prior notice due to maintenance, failures, communication line problems and the like.
3. Except in cases of the operator's willful misconduct or gross negligence, the operator is not liable for damages arising from your use of the App.
"""),
            Section(heading: "Article 9 (Account Deletion)", body: """
You may delete your account at any time from "My Page" → "Delete Account" within the App. Once deleted, your profile, photos, meetups, group chat history and other data will be permanently removed and cannot be restored.
"""),
            Section(heading: "Article 10 (Changes to These Terms)", body: """
The operator may change these Terms when it deems necessary. Users will be notified within the App of any material changes.
"""),
            Section(heading: "Article 11 (Governing Law and Jurisdiction)", body: """
These Terms are governed by the laws of Japan. Any dispute relating to the App shall be subject to the exclusive jurisdiction of the court having jurisdiction over the operator's location as the court of first instance.
""")
        ]
    )

    static let privacyEN = LegalDocument(
        title: "Privacy Policy",
        updatedAt: "September 8, 2026",
        sections: [
            Section(heading: "Introduction", body: """
This Privacy Policy sets out how user information is handled in CamMatch (the "App"), a group-meetup app exclusively for university students.
Contact: \(contactEmail)
"""),
            Section(heading: "1. Information We Collect", body: """
[Information you provide]
・Account information: the email address issued by your university, and your password (stored hashed)
・Profile information: full name, date of birth, place of residence, university, major, height, nationality, languages spoken, body type, drinking and smoking habits, self-introduction, short comment, hobby cards
・Photos: profile photos
・Meetup information: meetups you host, applications you send, and group chat messages

[Information recorded automatically]
・Activity history: last active time
・Safety information: hide/block settings and report content

The App does not collect advertising or tracking identifiers (IDFA) and does not sell information to third parties. It does not collect location data; only the region you select yourself is used.
"""),
            Section(heading: "2. Purposes of Use", body: """
1. To provide, maintain and improve the App
2. To verify enrollment and identity via your university email address
3. To provide meetup postings, applications and group chats
4. To detect, investigate and respond to violations of the Terms, impersonation and other misconduct
5. To respond to your inquiries
6. To comply with applicable laws
"""),
            Section(heading: "3. Disclosure to Third Parties and Outsourcing", body: """
The operator does not provide your personal information to third parties except in the following cases:
・With your consent
・Where required by law, or necessary to protect a person's life, body or property
・In response to a lawful disclosure request from a court, the police or another public authority

The App also uses the following external services:
・Supabase, Inc. (authentication, database, image storage)
・Apple Inc. (App Store)

The servers of these services may be located outside Japan.
"""),
            Section(heading: "4. Information Shown to Other Users", body: """
Given the nature of the App, the following information is visible to other users. Please do not register information you do not want to be seen.

・Full name, age, place of residence, university, major, height, nationality, languages spoken, body type, drinking and smoking habits
・Self-introduction, short comment, hobby cards
・Profile photos
・Online status (can be turned off in settings)

Your email address, your exact date of birth (only your age is shown) and your password are never shown to other users. Gender is not shown to other users, and no search or filtering by gender is provided.
"""),
            Section(heading: "5. Your Settings and Rights", body: """
・Editing your profile: you can change it at any time from "My Page".
・Adjusting visibility: you can turn off the display of your online status.
・Deleting your account: you can delete it yourself at any time from "My Page" → "Delete Account".
・Requests for disclosure, correction or suspension of use: please contact us. After verifying your identity, we will respond in accordance with applicable law.
"""),
            Section(heading: "6. Retention Period", body: """
User information is retained while your account exists. After you delete your account we remove it promptly, except for information we are required by law to retain and the minimum records needed to handle violations and prevent re-registration, which may be kept to the extent and for the period necessary.
"""),
            Section(heading: "7. Security Measures", body: """
・All communication is encrypted with TLS.
・Passwords are stored hashed; the operator cannot see them in plaintext.
・Row-level security (RLS) is configured on the database so that content such as group chats of meetups you are not part of cannot be accessed without permission.
"""),
            Section(heading: "8. Use by Minors", body: """
The App is available only to users aged 18 or over who are enrolled at a university or similar institution. Registration and use by anyone under 18 is strictly prohibited.
"""),
            Section(heading: "9. Changes to This Policy", body: """
This Policy may be revised in response to changes in law or the addition of new features. Users will be notified within the App of any material changes.
""")
        ]
    )

    enum Kind {
        case terms
        case privacy
    }

    static func resolved(_ kind: Kind, locale: Locale) -> LegalDocument {
        let isJapanese = locale.language.languageCode?.identifier == "ja"
        switch kind {
        case .terms: return isJapanese ? .termsJA : .termsEN
        case .privacy: return isJapanese ? .privacyJA : .privacyEN
        }
    }
}

/// 規約・ポリシーを表示する共通画面。
/// アプリの表示言語設定(日本語/英語)に応じて、本文を自動的に切り替える。
struct LegalDocumentView: View {
    let document: LegalDocument.Kind
    @Environment(\.locale) private var locale

    private var resolvedDocument: LegalDocument {
        LegalDocument.resolved(document, locale: locale)
    }

    var body: some View {
        let document = resolvedDocument
        ZStack {
            Color.appListBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("最終更新日: \(document.updatedAt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.brandPurple)
                            Text(section.body)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LegalDocumentView(document: .terms)
    }
}
