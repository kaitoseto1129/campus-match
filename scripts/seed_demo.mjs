// App Review 用のデモデータを投入する。
//
// 審査専用の大学「サンプル大学」(example.ac.jp)を作り、そこに審査用アカウントと架空の学生、
// 集まり・応募・グループトークを入れる。集まりは大学ごとに分かれるので、実際の利用者には見えない。
//
// 事前準備:
//   1. .env.local に SUPABASE_DB_URL(apply-sql.mjs と同じ)と、審査用アカウントのパスワードを書く
//        DEMO_ACCOUNT_PASSWORD=xxxx
//   2. サムネイル画像を生成する:  swift scripts/render_demo_thumbs.swift scripts/demo_img
//      アバター画像は scripts/demo_img/a_<seed>.png に置く(DiceBear等で生成したもの)
//
// 使い方:
//   node scripts/seed_demo.mjs           … 投入(既存のデモデータがあれば消してから作り直す)
//   node scripts/seed_demo.mjs --clean   … デモデータを全部消すだけ(審査が終わったら実行する)
import { writeFileSync, readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
function loadEnv(key) {
  if (process.env[key]) return process.env[key];
  const envPath = resolve(repoRoot, ".env.local");
  if (!existsSync(envPath)) return null;
  const m = readFileSync(envPath, "utf8").match(new RegExp(`^\\s*${key}\\s*=\\s*(.+)\\s*$`, "m"));
  return m ? m[1].replace(/^["']|["']$/g, "") : null;
}
const DB_URL = loadEnv("SUPABASE_DB_URL");
const PASSWORD = loadEnv("DEMO_ACCOUNT_PASSWORD");
if (!DB_URL || !PASSWORD) {
  console.error(".env.local に SUPABASE_DB_URL と DEMO_ACCOUNT_PASSWORD を設定してください");
  process.exit(1);
}
const sql = postgres(DB_URL, { ssl: "require", max: 1, prepare: false, onnotice: () => {} });

const SUPABASE_URL = "https://mqmhzroizlszdeoqxydg.supabase.co";
const ANON_KEY = "sb_publishable_W5_v1sAFCRWrckJ1zAwU4Q_OEuhFl4S";
const DOMAIN = "example.ac.jp";

const clean = process.argv.includes("--clean");
const jst = (daysAhead, hh, mm = 0) => {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() + daysAhead);
  // JSTの hh:mm = UTC の hh-9
  d.setUTCHours(hh - 9, mm);
  return d.toISOString();
};
const ago = (minutes) => new Date(Date.now() - minutes * 60_000).toISOString();

// ---------------------------------------------------------------- 登場人物
const people = [
  { key: "reviewer", email: "applereview@example.ac.jp", name: "佐藤 陽菜", birthday: "2005-04-18", major: "社会学", tagline: "ご飯行ける人募集中🍜", hobby: ["cafe", "gourmet", "reading", "movie"],
    description: "社会学部の2年です。人と話すのが好きで、色々な学科の人と知り合いたくてこのアプリを始めました。週末はカフェで本を読んでいることが多いです。ご飯や勉強会など、気軽に誘ってください！", drinking: "時々飲む", smoking: "吸わない", languages: ["日本語", "英語"], seed: "hina" },
  // 審査員が「退会」を試すための2つ目のアカウント。集まりには一切関わらせない
  // (審査用アカウント本体を退会されるとデモデータが丸ごと消えてしまうため)。
  { key: "reviewer2", email: "applereview2@example.ac.jp", name: "山本 大地", birthday: "2005-09-21", major: "法学", tagline: "よろしくお願いします", hobby: ["movie", "music"],
    description: "法学部2年です。まだ始めたばかりですが、いろいろな集まりに参加してみたいと思っています。映画と音楽が好きです。気軽に声をかけてください。", drinking: "時々飲む", smoking: "吸わない", languages: ["日本語"], seed: "daichi" },
  { key: "tanaka", email: "ren.tanaka@example.ac.jp", name: "田中 蓮", birthday: "2004-11-02", major: "機械工学", tagline: "ラーメン屋を開拓中", hobby: ["gourmet", "running", "game"],
    description: "工学部3年。研究室が忙しいので、息抜きに誰かとご飯に行くのが楽しみです。ラーメンは月10杯ペース。駅周辺の店はだいたい把握してるので案内できます。", drinking: "飲む", smoking: "吸わない", languages: ["日本語"], seed: "ren" },
  { key: "suzuki", email: "misaki.suzuki@example.ac.jp", name: "鈴木 美咲", birthday: "2005-07-25", major: "国際関係学", tagline: "山とカメラ📷", hobby: ["camp", "photo", "travel", "cafe"],
    description: "国際関係学部2年。休みの日はハイキングや旅行に出かけるのが好きです。写真を撮るのも好きなので、一緒に出かけてくれる人を探しています。初心者向けの山なら案内できます！", drinking: "飲まない", smoking: "吸わない", languages: ["日本語", "英語", "韓国語"], seed: "misaki" },
  { key: "takahashi", email: "daiki.takahashi@example.ac.jp", name: "高橋 大輝", birthday: "2004-02-14", major: "経営学", tagline: "フットサル毎週やってます⚽", hobby: ["gym", "sports_watch", "running"],
    description: "経営学部3年。高校までサッカー部でした。今は週1でフットサルをやっていて、いつも人数がギリギリなので一緒にやってくれる人を探しています。経験は問いません、楽しくやりましょう。", drinking: "飲む", smoking: "吸わない", languages: ["日本語"], seed: "daiki" },
  { key: "ito", email: "sakura.ito@example.ac.jp", name: "伊藤 さくら", birthday: "2006-01-09", major: "教育学", tagline: "学祭実行委員です🎪", hobby: ["festival", "music", "sweets", "karaoke"],
    description: "教育学部1年。学祭実行委員をやっていて、今年の学祭を盛り上げるために色んな人と知り合いたいです。甘いもの巡りとカラオケが好きです。イベント系の集まりをよく立てます。", drinking: "飲まない", smoking: "吸わない", languages: ["日本語"], seed: "sakura" },
  { key: "watanabe", email: "shota.watanabe@example.ac.jp", name: "渡辺 翔太", birthday: "2004-09-30", major: "コンピューターサイエンス", tagline: "ボドゲ持ってます🎲", hobby: ["game", "programming", "anime"],
    description: "情報学部3年。ボードゲームを20種類くらい持っているので、定期的にボドゲ会を開いています。カタン、ドミニオン、コードネームあたりが定番です。初心者でもルール説明するので大丈夫です。", drinking: "時々飲む", smoking: "吸わない", languages: ["日本語", "英語"], seed: "shota" },
  { key: "nakamura", email: "yui.nakamura@example.ac.jp", name: "中村 結衣", birthday: "2005-05-12", major: "英文学・英語学", tagline: "留学から帰ってきました🇬🇧", hobby: ["language", "reading", "cafe", "movie"],
    description: "文学部2年。去年イギリスに1年留学していました。英語を忘れたくないので、英語で雑談できる場を作っています。日本語混じりで全然OKなので、気軽に来てください。", drinking: "時々飲む", smoking: "吸わない", languages: ["日本語", "英語"], seed: "yui" },
  { key: "kobayashi", email: "yuto.kobayashi@example.ac.jp", name: "小林 悠人", birthday: "2005-12-03", major: "経済学", tagline: "誘われたら大体行きます", hobby: ["gourmet", "drive", "music"],
    description: "経済学部2年。一人暮らしなので誰かとご飯に行くのが好きです。車も持っているので、ドライブや遠出の集まりも大歓迎です。フットワークは軽い方だと思います。", drinking: "飲む", smoking: "吸わない", languages: ["日本語"], seed: "yuto" },
];

// ---------------------------------------------------------------- 集まり
const gatherings = [
  { key: "ramen", host: "tanaka", title: "木曜の夜、駅前のラーメン行きませんか？", category: "ご飯", location: "高田馬場駅 早稲田口の改札前", at: jst(13, 19, 0), capacity: 4, duration: 2,
    description: "最近見つけた煮干し系のラーメン屋に行きたいです。19時に改札前で集合して歩いて5分くらい。辛いのが苦手な人でも大丈夫なメニューがあります。", photo: "ramen",
    applications: [{ who: "reviewer", status: "accepted", comment: "ラーメン大好きです！ぜひ行きたいです" }, { who: "kobayashi", status: "accepted", comment: "煮干し系気になってました" }],
    messages: [
      { who: "tanaka", body: "承認しました！19時に早稲田口の改札前集合でいいですか？", min: 180 },
      { who: "reviewer", body: "はい、大丈夫です！楽しみにしてます🍜", min: 170 },
      { who: "kobayashi", body: "よろしくお願いします。辛いの得意な人います？", min: 120 },
      { who: "tanaka", body: "僕は普通です笑 辛くないメニューもあるので安心してください。おすすめ案内しますね", min: 95 },
      { who: "reviewer", body: "ありがとうございます！当日よろしくお願いします", min: 40 },
      { who: "kobayashi", body: "少し早く着きそうなので、先に並んでおきますね", min: 12 },
    ],
    reads: { reviewer: 60, kobayashi: 5, tanaka: 5 } },
  { key: "cafe", host: "reviewer", title: "図書館前のカフェで一緒にレポート進めませんか", category: "カフェ・勉強", location: "大学図書館1階のカフェ", at: jst(10, 14, 0), capacity: 3, duration: 3,
    description: "来週締切のレポートを一緒に進めたいです。黙々とやる時間と、休憩でおしゃべりする時間を交互に。学部は問いません。コンセントのある席を確保しておきます。", photo: "cafe",
    applications: [{ who: "suzuki", status: "pending", comment: "同じ授業取ってます！ぜひ一緒にやりたいです" }, { who: "watanabe", status: "pending", comment: "レポート溜まってるので参加させてください" }],
    messages: [], reads: {} },
  { key: "futsal", host: "takahashi", title: "土曜午後、フットサル人数足りません！初心者歓迎", category: "スポーツ・アウトドア", location: "都立公園のフットサルコート", at: jst(16, 15, 0), capacity: 8, duration: 2,
    description: "毎週やってるフットサルですが今週は人数が足りません。経験ゼロでも全然OK、ボールを蹴ったことがあれば十分です。運動できる服と靴だけ持ってきてください。コート代は割り勘で1人500円くらいです。", photo: "futsal",
    applications: [{ who: "nakamura", status: "accepted", comment: "運動不足なので参加したいです" }, { who: "ito", status: "accepted", comment: "初心者ですが大丈夫ですか？" }],
    messages: [
      { who: "takahashi", body: "2人とも承認しました！当日は14:45に公園の入口集合で", min: 300 },
      { who: "ito", body: "了解です！シューズは普通のスニーカーでいいですか？", min: 280 },
      { who: "takahashi", body: "全然大丈夫です👍", min: 275 },
    ],
    reads: { takahashi: 200, nakamura: 200, ito: 200 } },
  { key: "hiking", host: "suzuki", title: "高尾山ハイキング行きませんか🍁", category: "遊び・観光", location: "京王線 高尾山口駅", at: jst(19, 9, 0), capacity: 5, duration: 6,
    description: "紅葉が始まる前に高尾山に行きたいです。初心者向けのコースなので、普段運動しない人でも大丈夫。朝9時に高尾山口駅に集合して、お昼は山頂で食べる予定です。帰りに温泉も寄ります。", photo: "hiking", deadline: jst(17, 21, 0),
    applications: [{ who: "reviewer", status: "pending", comment: "初めてですが、体力には自信あります！" }, { who: "kobayashi", status: "accepted", comment: "温泉に惹かれました" }],
    messages: [
      { who: "suzuki", body: "小林さん承認しました！他にも何人か来そうなので待ちましょう", min: 600 },
      { who: "kobayashi", body: "了解です、楽しみにしてます", min: 590 },
    ],
    reads: { suzuki: 500, kobayashi: 500 } },
  { key: "festival", host: "ito", title: "学祭の出し物、一緒に見て回りませんか", category: "イベント参加", location: "正門前の時計台", at: jst(21, 12, 0), capacity: 6, duration: 4,
    description: "学祭実行委員なので裏事情も話せます笑 おすすめの模擬店を順番に回って、午後はステージ企画を見る予定。一人だと回りにくいという人、ぜひ。", photo: "festival",
    applications: [{ who: "tanaka", status: "pending", comment: "実行委員のおすすめ気になります" }],
    messages: [], reads: {} },
  { key: "boardgame", host: "watanabe", title: "ボードゲーム会やります🎲 カタン初心者OK", category: "遊び・観光", location: "学生会館2階 フリースペース", at: jst(12, 18, 0), capacity: 6, duration: 3, deadline: jst(11, 12, 0),
    description: "カタン、ドミニオン、コードネームあたりを持っていきます。ルールは全部説明するので初めてでも大丈夫。お菓子持ち寄り歓迎です。", photo: "boardgame",
    applications: [{ who: "takahashi", status: "accepted", comment: "カタンやったことあります" }],
    messages: [{ who: "watanabe", body: "承認しました！当日はカタンから始めましょう", min: 1400 }],
    reads: { watanabe: 1300, takahashi: 1300 } },
  { key: "english", host: "nakamura", title: "英語で雑談する会（日本語OK）", category: "その他", location: "学食の奥のテーブル", at: jst(14, 12, 15), capacity: 5, duration: 1,
    description: "お昼を食べながら英語で雑談しませんか。文法は気にせず、分からなくなったら日本語でOK。留学に興味がある人、TOEICの勉強中の人、大歓迎です。", photo: "english",
    applications: [],
    messages: [], reads: {} },
];

// ---------------------------------------------------------------- 写真の取得元
const localImage = (name) => {
  const buf = readFileSync(resolve(repoRoot, "scripts/demo_img", name));
  return { buf, type: name.endsWith(".png") ? "image/png" : "image/jpeg" };
};

// ---------------------------------------------------------------- 実行
async function removeObjects(token, bucket, prefix) {
  // Storage API 経由でしか消せない(storage.objects への直接DELETEは保護されている)。
  const list = await fetch(`${SUPABASE_URL}/storage/v1/object/list/${bucket}`, {
    method: "POST", headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ prefix, limit: 100 }),
  });
  if (!list.ok) return 0;
  const names = (await list.json()).map((o) => `${prefix}/${o.name}`);
  if (!names.length) return 0;
  await fetch(`${SUPABASE_URL}/storage/v1/object/${bucket}`, {
    method: "DELETE", headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ prefixes: names }),
  });
  return names.length;
}

async function cleanup() {
  const [univ] = await sql`select id from universities where domain = ${DOMAIN}`;
  if (!univ) { console.log("デモデータはありません"); return; }
  const users = await sql`select p.id, u.email from profiles p join auth.users u on u.id = p.id where p.university_id = ${univ.id}`;
  const ids = users.map((u) => u.id);
  if (ids.length) {
    let removed = 0;
    for (const u of users) {
      let token;
      try { token = await signIn(u.email); } catch { continue; }
      removed += await removeObjects(token, "profile_photos", u.id);
      for (const g of await sql`select id from gatherings where host_id = ${u.id}`) {
        removed += await removeObjects(token, "gathering_photos", g.id);
      }
    }
    console.log(`  Storage のファイルを ${removed} 件削除`);
    await sql`delete from gatherings where host_id in ${sql(ids)}`; // applications/messages/reads は cascade
    await sql`delete from profile_photos where user_id in ${sql(ids)}`;
    await sql`delete from user_actions where actor_id in ${sql(ids)} or target_id in ${sql(ids)}`;
    await sql`delete from reports where reporter_id in ${sql(ids)} or reported_id in ${sql(ids)}`;
    await sql`delete from push_tokens where user_id in ${sql(ids)}`;
    await sql`delete from profiles where id in ${sql(ids)}`;
    await sql`delete from auth.identities where user_id in ${sql(ids)}`;
    await sql`delete from auth.users where id in ${sql(ids)}`;
  }
  await sql`delete from universities where id = ${univ.id}`;
  console.log(`デモデータを削除しました (ユーザー${ids.length}人)`);
}

async function signIn(email) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST", headers: { apikey: ANON_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: PASSWORD }),
  });
  if (!res.ok) throw new Error(`sign in failed for ${email}: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}

async function withRetry(label, fn, tries = 4) {
  let lastError;
  for (let i = 1; i <= tries; i++) {
    try { return await fn(); } catch (e) {
      lastError = e;
      console.log(`    ${label}: ${i}回目失敗 (${e.cause?.code ?? e.message.slice(0, 60)}) → 再試行`);
      await new Promise((r) => setTimeout(r, 1500 * i));
    }
  }
  throw lastError;
}

async function download(url) {
  return withRetry("download", async () => {
    const res = await fetch(url, { redirect: "follow" });
    if (!res.ok) throw new Error(`download failed ${url}: ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    const type = res.headers.get("content-type")?.split(";")[0] ?? "";
    if (!type.startsWith("image/") || buf.length < 1000) throw new Error(`not an image: ${type} ${buf.length}B`);
    return { buf, type };
  });
}

async function upload(token, bucket, path, { buf, type }) {
  return withRetry("upload", async () => {
    const res = await fetch(`${SUPABASE_URL}/storage/v1/object/${bucket}/${path}`, {
      method: "POST", headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}`, "Content-Type": type, Connection: "close" }, body: buf,
    });
    if (!res.ok) throw new Error(`upload failed ${bucket}/${path}: ${res.status} ${await res.text()}`);
    return `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${path}`;
  });
}

async function seed() {
  await cleanup();

  console.log("\n1. 大学とユーザーを作成");
  const [univ] = await sql`insert into universities (name, domain, country, prefecture) values ('サンプル大学', ${DOMAIN}, '日本', '東京都') returning id`;
  const ids = {};
  for (const p of people) {
    const [u] = await sql`
      insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, last_sign_in_at, confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current, phone_change, phone_change_token, reauthentication_token)
      values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', ${p.email},
        extensions.crypt(${PASSWORD}, extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}'::jsonb,
        ${sql.json({ display_name: p.name })}, now() - interval '20 days', now(), now(), '', '', '', '', '', '', '', '')
      returning id`;
    ids[p.key] = u.id;
    await sql`insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at, last_sign_in_at)
      values (gen_random_uuid(), ${u.id}, ${u.id}, 'email', ${sql.json({ sub: u.id, email: p.email, display_name: p.name, email_verified: true, phone_verified: false })}, now(), now(), now())`;
    await sql`update profiles set
      birthday = ${p.birthday}, description = ${p.description}, tagline = ${p.tagline}, major = ${p.major},
      area = '東京都', city = '新宿区', nationality = '日本', nationalities = '{"日本"}', languages = ${p.languages},
      hobby_cards = ${p.hobby}, drinking = ${p.drinking}, smoking = ${p.smoking},
      last_active_at = now() - (random() * interval '6 hours'), created_at = now() - interval '20 days'
      where id = ${u.id}`;
    console.log(`  ${p.name} (${p.email})`);
  }

  console.log("\n2. プロフィール写真をアップロード");
  const tokens = {};
  for (const p of people) {
    tokens[p.key] = await signIn(p.email);
    const img = localImage(`a_${p.seed}.png`);
    const url = await upload(tokens[p.key], "profile_photos", `${ids[p.key]}/${crypto.randomUUID()}.png`, img);
    await sql`insert into profile_photos (user_id, url, order_number) values (${ids[p.key]}, ${url}, 0)`;
    await sql`update profiles set profile_image_url = ${url} where id = ${ids[p.key]}`;
    console.log(`  ${p.name} ✓`);
  }

  console.log("\n3. 集まりを作成");
  const gids = {};
  for (const g of gatherings) {
    const existing = await withRetry("check", () => sql`select id from gatherings where host_id = ${ids[g.host]} and title = ${g.title}`);
    if (existing.length) { console.log(`  ${g.title} (既にあり、スキップ)`); gids[g.key] = existing[0].id; continue; }
    const [row] = await withRetry("insert gathering", () => sql`insert into gatherings (host_id, university_id, title, description, location, scheduled_at, capacity, status, category, duration_hours, deadline_at, created_at)
      values (${ids[g.host]}, ${univ.id}, ${g.title}, ${g.description}, ${g.location}, ${g.at}, ${g.capacity}, 'open', ${g.category}, ${g.duration}, ${g.deadline ?? null}, now() - (random() * interval '5 days'))
      returning id`);
    gids[g.key] = row.id;
    const img = localImage(`g_${g.photo}.jpg`);
    const url = await upload(tokens[g.host], "gathering_photos", `${row.id}/${crypto.randomUUID()}.jpg`, img);
    await withRetry("update image", () => sql`update gatherings set image_url = ${url} where id = ${row.id}`);
    for (const a of g.applications) {
      await sql`insert into gathering_applications (gathering_id, applicant_id, comment, status, created_at, responded_at)
        values (${row.id}, ${ids[a.who]}, ${a.comment}, ${a.status}, now() - interval '2 days', ${a.status === "pending" ? null : ago(60 * 24)})`;
    }
    for (const m of g.messages) {
      await sql`insert into gathering_messages (gathering_id, sender_id, body, created_at) values (${row.id}, ${ids[m.who]}, ${m.body}, ${ago(m.min)})`;
    }
    for (const [who, min] of Object.entries(g.reads)) {
      await sql`insert into gathering_reads (gathering_id, user_id, last_read_at) values (${row.id}, ${ids[who]}, ${ago(min)})`;
    }
    console.log(`  ${g.title} (主催: ${people.find((p) => p.key === g.host).name}) ✓`);
  }

    console.log("\n完了。審査用アカウント: applereview@example.ac.jp (パスワードは .env.local の DEMO_ACCOUNT_PASSWORD)");
}

try {
  if (clean) await cleanup(); else await seed();
} finally {
  await sql.end({ timeout: 5 });
}
