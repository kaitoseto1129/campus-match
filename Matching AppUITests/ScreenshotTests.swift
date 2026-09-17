//
//  ScreenshotTests.swift
//  Matching AppUITests
//
//  App Store 用のスクリーンショットを自動で撮る。
//  デモアカウント(scripts/seed_demo.mjs で投入したもの)でログインし、主要画面を順番に開いて保存する。
//
//  実行例(iPhone 17 Pro Max = 6.9インチ):
//    TEST_RUNNER_SCREENSHOT_DIR=$HOME/Desktop/CamMatch_Screenshots \
//    TEST_RUNNER_DEMO_EMAIL=applereview@example.ac.jp \
//    TEST_RUNNER_DEMO_PASSWORD=xxxx \
//    xcodebuild test -project "Matching App.xcodeproj" -scheme "Matching App" \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//      -only-testing:"Matching AppUITests/ScreenshotTests"
//
//  TEST_RUNNER_ 接頭辞の環境変数はテストプロセスに接頭辞なしで渡される。
//  ステータスバーは事前に `xcrun simctl status_bar <udid> override --time 9:41 ...` で固定しておく。

import XCTest

final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDir: URL!
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        outputDir = URL(fileURLWithPath: env["SCREENSHOT_DIR"] ?? NSTemporaryDirectory())
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        app = XCUIApplication()
        // 端末の言語設定に関わらず日本語で撮る。
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        // Macのタイムゾーンに関わらず日本時間で日時を出す(Foundationは TZ 環境変数を尊重する)。
        app.launchEnvironment["TZ"] = "Asia/Tokyo"
        app.launch()
    }

    /// 画面を保存する。ファイルと、テスト結果(xcresult)の添付の両方に残す。
    private func snap(_ name: String) {
        shotIndex += 1
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let file = outputDir.appendingPathComponent(String(format: "%02d_%@.png", shotIndex, name))
        do { try shot.pngRepresentation.write(to: file) } catch { XCTFail("保存に失敗: \(file.path) \(error)") }
    }

    private func wait(_ element: XCUIElement, _ timeout: TimeInterval = 30, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(what) が表示されませんでした")
    }

    /// 画像の読み込みなど、要素の出現では待てないものを少し待つ。
    private func settle(_ seconds: TimeInterval = 2.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// 一覧のカードを開く。カードは NavigationLink(=Button)なので、タイトル文字を含むボタンを掴む。
    /// 画面下に半分隠れているとタップが当たらないため、見えるまでスクロールしてから押し、
    /// 詳細が開かなければもう一度だけやり直す。
    private func openGathering(titled title: String) {
        let card = app.buttons.containing(.staticText, identifier: title).firstMatch
        wait(card, 20, "「\(title)」のカード")
        for attempt in 0..<2 {
            var tries = 0
            while !card.isHittable && tries < 5 {
                app.swipeUp()
                settle(0.8)
                tries += 1
            }
            card.tap()
            if app.navigationBars["集まりの詳細"].waitForExistence(timeout: 8) { return }
            if attempt == 0 { settle(1) }
        }
        XCTFail("「\(title)」の詳細が開きませんでした")
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) { back.tap() }
        settle(1)
    }

    func testTakeScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        let email = env["DEMO_EMAIL"] ?? "applereview@example.ac.jp"
        guard let password = env["DEMO_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("TEST_RUNNER_DEMO_PASSWORD が設定されていません")
        }

        // ---- 初回起動のウォークスルー(次へ → はじめる) ----
        let next = app.buttons["次へ"]
        if next.waitForExistence(timeout: 15) {
            next.tap()
            let start = app.buttons["はじめる"]
            wait(start, 10, "ウォークスルーの「はじめる」")
            start.tap()
        }

        // ---- ログイン ----
        let loginSegment = app.segmentedControls.buttons["ログイン"]
        if loginSegment.waitForExistence(timeout: 20) {
            loginSegment.tap()
            let emailField = app.textFields["メールアドレス"]
            wait(emailField, 10, "メールアドレス欄")
            emailField.tap()
            emailField.typeText(email)
            let passwordField = app.secureTextFields["パスワード"]
            wait(passwordField, 10, "パスワード欄")
            passwordField.tap()
            passwordField.typeText(password)
            // セグメントの「ログイン」と区別するため、一番下にあるボタンを選ぶ。
            let loginButtons = app.buttons.matching(NSPredicate(format: "label == 'ログイン'")).allElementsBoundByIndex
            let submit = loginButtons.max(by: { $0.frame.minY < $1.frame.minY })!
            submit.tap()
        }

        // ログイン後の読み込みには時間がかかる。集まり一覧が出るまで待ちつつ、
        // 途中で初回だけ出る通知の案内が出たらスキップする。
        let ramen = app.staticTexts["木曜の夜、駅前のラーメン行きませんか？"]
        let later = app.buttons["あとで設定する"]
        let deadline = Date().addingTimeInterval(120)
        while !ramen.exists && Date() < deadline {
            if later.exists { later.tap() }
            settle(1)
        }
        wait(ramen, 5, "集まり一覧")
        // 一覧ではなく詳細が開いてしまっていることがあったため、一覧に戻してから撮る。
        for _ in 0..<3 where app.navigationBars["集まりの詳細"].exists {
            goBack()
        }
        wait(app.navigationBars["集まり"], 10, "集まり一覧のタイトル")
        settle(4) // サムネイル画像の読み込み待ち
        snap("gatherings_list")

        // ---- 2. 集まり詳細(参加確定) → 3. グループトーク ----
        openGathering(titled: "木曜の夜、駅前のラーメン行きませんか？")
        let openChat = app.buttons["グループトークを開く"]
        wait(openChat, 20, "集まり詳細")
        settle(3)
        snap("gathering_detail")
        openChat.tap()
        wait(app.staticTexts["承認しました！19時に早稲田口の改札前集合でいいですか？"], 20, "グループトーク")
        settle(2)
        snap("group_chat")
        goBack()
        goBack()
        app.swipeDown(); settle(0.5)

        // ---- 4. 自分が主催(応募待ちあり) → 5. その詳細 ----
        app.segmentedControls.buttons["自分が主催"].tap()
        let cafe = app.staticTexts["図書館前のカフェで一緒にレポート進めませんか"]
        wait(cafe, 20, "自分が主催の一覧")
        settle(3)
        snap("hosted_list")
        openGathering(titled: "図書館前のカフェで一緒にレポート進めませんか")
        wait(app.staticTexts["応募一覧"], 20, "主催している集まりの詳細")
        settle(3)
        snap("hosted_detail_applications")
        goBack()

        // ---- 6. 募集フォーム ----
        app.segmentedControls.buttons["みんなの募集"].tap()
        let create = app.buttons["createGatheringButton"]
        wait(create, 10, "募集ボタン")
        create.tap()
        wait(app.staticTexts["何をしますか?"], 10, "募集フォーム")
        settle(1.5)
        snap("create_gathering")
        app.buttons["closeCreateGatheringButton"].tap()
        settle(1)

        // ---- 7. マイページ → 8. プロフィール ----
        app.buttons["マイページ"].firstMatch.tap()
        let editProfile = app.buttons["プロフィールを確認・編集"]
        wait(editProfile, 20, "マイページ")
        settle(3)
        snap("my_page")
        editProfile.tap()
        wait(app.staticTexts["基本情報"], 20, "プロフィール")
        settle(3)
        snap("profile")
    }
}
