import AppKit

struct Card { let file: String; let emoji: String; let title: String; let sub: String; let c1: NSColor; let c2: NSColor }
func rgb(_ h: UInt32) -> NSColor { NSColor(red: CGFloat((h >> 16) & 0xff)/255, green: CGFloat((h >> 8) & 0xff)/255, blue: CGFloat(h & 0xff)/255, alpha: 1) }

let cards: [Card] = [
  Card(file: "g_ramen",     emoji: "🍜", title: "木曜の夜、駅前でラーメン",  sub: "高田馬場 ・ 19:00",      c1: rgb(0xF97316), c2: rgb(0xDC2626)),
  Card(file: "g_cafe",      emoji: "☕️", title: "カフェでレポート会",        sub: "図書館1F ・ 14:00",      c1: rgb(0xA16207), c2: rgb(0x78350F)),
  Card(file: "g_futsal",    emoji: "⚽️", title: "土曜フットサル 人数募集",   sub: "都立公園コート ・ 15:00", c1: rgb(0x16A34A), c2: rgb(0x0F766E)),
  Card(file: "g_hiking",    emoji: "🏔", title: "高尾山ハイキング",          sub: "高尾山口駅 ・ 9:00",     c1: rgb(0x0EA5E9), c2: rgb(0x1D4ED8)),
  Card(file: "g_festival",  emoji: "🎪", title: "学祭を一緒に回ろう",        sub: "正門前 ・ 12:00",        c1: rgb(0xEC4899), c2: rgb(0x9333EA)),
  Card(file: "g_boardgame", emoji: "🎲", title: "ボードゲーム会",            sub: "学生会館2F ・ 18:00",    c1: rgb(0x8B5CF6), c2: rgb(0x4C1D95)),
  Card(file: "g_english",   emoji: "🗣", title: "英語で雑談する会",          sub: "学食 ・ 12:15",          c1: rgb(0x14B8A6), c2: rgb(0x0E7490)),
]

let W: CGFloat = 1280, H: CGFloat = 720
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])

for card in cards {
  let img = NSImage(size: NSSize(width: W, height: H))
  img.lockFocus()
  guard let ctx = NSGraphicsContext.current?.cgContext else { continue }

  // 斜めグラデーション
  let grad = NSGradient(colors: [card.c1, card.c2])!
  grad.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -30)

  // 奥に大きな半透明の円をいくつか(のっぺり防止)
  for (i, r) in [(x: W*0.82, y: H*0.75, r: 260.0), (x: W*0.15, y: H*0.1, r: 200.0), (x: W*0.6, y: -40.0, r: 150.0)].enumerated() {
    ctx.setFillColor(NSColor.white.withAlphaComponent(i == 0 ? 0.10 : 0.07).cgColor)
    ctx.fillEllipse(in: CGRect(x: r.x - r.r, y: r.y - r.r, width: r.r*2, height: r.r*2))
  }

  // 絵文字
  let emojiAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 240)]
  let emojiSize = (card.emoji as NSString).size(withAttributes: emojiAttr)
  (card.emoji as NSString).draw(at: NSPoint(x: W*0.80 - emojiSize.width/2, y: H/2 - emojiSize.height/2 + 10), withAttributes: emojiAttr)

  // タイトル(左下)
  let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.25); shadow.shadowBlurRadius = 8; shadow.shadowOffset = NSSize(width: 0, height: -2)
  let titleAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 62, weight: .heavy), .foregroundColor: NSColor.white, .shadow: shadow]
  let subAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(0.85), .shadow: shadow]
  (card.title as NSString).draw(in: NSRect(x: 72, y: 190, width: 700, height: 160), withAttributes: titleAttr)
  (card.sub as NSString).draw(at: NSPoint(x: 74, y: 130), withAttributes: subAttr)

  // 左上に小さなラベル
  let tagAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: NSColor.white]
  let tag = "サンプル大学の集まり" as NSString
  let tagSize = tag.size(withAttributes: tagAttr)
  let pill = NSBezierPath(roundedRect: NSRect(x: 72, y: H - 72 - 44, width: tagSize.width + 40, height: 44), xRadius: 22, yRadius: 22)
  NSColor.white.withAlphaComponent(0.22).setFill(); pill.fill()
  tag.draw(at: NSPoint(x: 92, y: H - 72 - 44 + 8), withAttributes: tagAttr)

  img.unlockFocus()
  guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
        let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) else { continue }
  try! jpg.write(to: outDir.appendingPathComponent("\(card.file).jpg"))
  print("ok \(card.file).jpg \(jpg.count / 1024)KB")
}
