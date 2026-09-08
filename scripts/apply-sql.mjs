// SupabaseのPostgresに直接つないで、SQLファイルをそのまま流すツール。
//
// このリポジトリのマイグレーションは supabase/*.sql に置いてあり、これまでは
// Dashboard の SQL Editor に手で貼り付けて適用していた。貼り忘れ・貼り間違いを
// 避けるため、ファイルをそのまま適用できるようにしている。
//
// 使い方:
//   1. リポジトリ直下に .env.local を作り、接続文字列を1行書く(.gitignore済み)
//        SUPABASE_DB_URL=postgresql://postgres:<パスワード>@db.<ref>.supabase.co:5432/postgres
//      Supabase Dashboard > Project Settings > Database > Connection string > URI
//      ※ Session pooler (6543) ではなく Direct connection (5432) を使うこと。
//         DDL(トランザクション内のCREATE/DROP)がpoolerだと通らないことがある。
//   2. まず中身を確認する(接続もするが何も変更しない):
//        node scripts/apply-sql.mjs supabase/xxx.sql --dry-run
//   3. 実際に適用する:
//        node scripts/apply-sql.mjs supabase/xxx.sql --yes
//
// --yes を付けない限り絶対に実行しない。DROP TABLE を含むファイルもあるため。

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function loadConnectionString() {
  if (process.env.SUPABASE_DB_URL) return process.env.SUPABASE_DB_URL;

  const envPath = resolve(repoRoot, ".env.local");
  if (!existsSync(envPath)) return null;
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const match = line.match(/^\s*SUPABASE_DB_URL\s*=\s*(.+)\s*$/);
    if (match) return match[1].replace(/^["']|["']$/g, "");
  }
  return null;
}

/// パスワードを画面にもログにも出さないための表示用。
function safeLabel(connectionString) {
  try {
    const url = new URL(connectionString);
    return `${url.username}@${url.hostname}:${url.port || 5432}${url.pathname}`;
  } catch {
    return "(接続文字列を解釈できませんでした)";
  }
}

const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith("--"));
const dryRun = args.includes("--dry-run");
const confirmed = args.includes("--yes");

if (!file) {
  console.error("使い方: node scripts/apply-sql.mjs <SQLファイル> [--dry-run | --yes]");
  process.exit(1);
}

const sqlPath = resolve(repoRoot, file);
if (!existsSync(sqlPath)) {
  console.error(`SQLファイルが見つかりません: ${sqlPath}`);
  process.exit(1);
}
const text = readFileSync(sqlPath, "utf8");

const connectionString = loadConnectionString();
if (!connectionString) {
  console.error(
    "接続文字列が見つかりません。\n" +
      "リポジトリ直下の .env.local に次の1行を書いてください(このファイルは.gitignore済みです):\n" +
      "  SUPABASE_DB_URL=postgresql://postgres:<パスワード>@db.<ref>.supabase.co:5432/postgres"
  );
  process.exit(1);
}

console.log(`接続先: ${safeLabel(connectionString)}`);
console.log(`SQLファイル: ${file} (${text.split("\n").length}行)`);

// 破壊的な操作が含まれていれば、実行前に必ず目に入るようにする。
// 関数定義($$ ... $$)の中身は「今そこで実行される文」ではなく定義の一部なので除外する
// (delete_own_account の中のdeleteまで並べると、実際より危なく見えてしまうため)。
const destructive = [];
let insideBody = false;
text.split("\n").forEach((rawLine, index) => {
  const line = rawLine.trim();
  const dollarQuotes = rawLine.match(/\$[a-zA-Z_]*\$/g) ?? [];
  if (dollarQuotes.length % 2 === 1) {
    insideBody = !insideBody;
    return;
  }
  if (insideBody || line.startsWith("--")) return;
  if (/^(drop|truncate|delete|update)\s/i.test(line)) destructive.push([index + 1, line]);
});
if (destructive.length > 0) {
  console.log("\n--- データを変更・削除する行 ---");
  for (const [lineNo, line] of destructive) console.log(`  ${lineNo}: ${line}`);
  console.log("--------------------------------\n");
}

if (!confirmed) {
  console.log(
    dryRun
      ? "--dry-run のため、接続確認だけ行って終了します。"
      : "--yes が指定されていないため実行しません。内容を確認のうえ --yes を付けて再実行してください。"
  );
}

const sql = postgres(connectionString, { ssl: "require", max: 1, prepare: false, onnotice: () => {} });

try {
  const [{ version }] = await sql`select version()`;
  console.log(`接続できました: ${version.split(",")[0]}`);

  if (!confirmed) process.exit(0);

  console.log("\n適用しています...");
  await sql.unsafe(text).simple();
  console.log("完了しました。");
} catch (error) {
  console.error(`\n失敗しました: ${error.message}`);
  if (error.position) console.error(`  位置: ${error.position}`);
  process.exitCode = 1;
} finally {
  await sql.end({ timeout: 5 });
}
