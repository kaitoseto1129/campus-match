// iOSアプリ(Matching App/Profile.swift)の固定選択肢と完全に同じ内容を保つこと。
// 片方だけ選択肢を変えると、既存データが一方のUIでは翻訳・表示できなくなるため。

export const UNSELECTED_OPTION = "-";

// App Store審査完了後、実際のURL(https://apps.apple.com/app/id...)に差し替える。
// nullの間はAppStoreButtonが「近日公開」表示にフォールバックする。
export const APP_STORE_URL: string | null = null;

export const drinkingOptions = [UNSELECTED_OPTION, "飲む", "時々飲む", "飲まない"];

export const smokingOptions = [
  UNSELECTED_OPTION,
  "吸わない",
  "禁煙中",
  "たまに吸う",
  "吸う",
];

export const personalityOptions = [
  UNSELECTED_OPTION,
  "明るい・社交的",
  "真面目・誠実",
  "優しい・思いやりがある",
  "面白い・ユーモアがある",
  "落ち着いている・マイペース",
];

export const majorOptions = [
  UNSELECTED_OPTION,
  "コンピューターサイエンス", "人工知能", "データサイエンス", "ソフトウェア工学", "サイバーセキュリティ",
  "情報システム", "情報技術", "コンピューター工学", "電気工学", "機械工学",
  "土木工学", "化学工学", "生体医工学", "航空宇宙工学", "経営・生産工学",
  "環境工学", "材料科学・工学", "ロボティクス", "メカトロニクス", "工学物理",
  "数学", "応用数学", "統計学", "保険数理", "物理学",
  "天文学", "化学", "生化学", "生物学", "分子生物学",
  "微生物学", "遺伝学", "神経科学", "認知科学", "環境科学",
  "地球科学", "地質学", "海洋生物学", "生態学", "農学",
  "心理学", "社会学", "人類学", "経済学", "政治学",
  "国際関係学", "公共政策", "行政学", "哲学", "歴史学",
  "地理学", "宗教学", "ジェンダー研究", "アフリカ系アメリカ研究", "アジア研究",
  "アメリカ研究", "言語学", "英文学・英語学", "比較文学", "創作・クリエイティブライティング",
  "コミュニケーション学", "ジャーナリズム", "メディア研究", "映画学", "広報・PR",
  "経営学", "金融学", "会計学", "マーケティング", "マネジメント",
  "起業学", "国際経営", "ビジネス分析", "サプライチェーン管理", "オペレーション管理",
  "人的資源管理", "ホスピタリティ経営", "不動産学", "建築学", "都市計画",
  "グラフィックデザイン", "工業デザイン", "インタラクションデザイン", "美術", "音楽",
  "演劇", "舞踊", "写真", "アニメーション", "ゲームデザイン",
  "教育学", "初等教育", "特別支援教育", "看護学", "公衆衛生学",
  "栄養学", "運動学", "スポーツマネジメント", "刑事司法学", "犯罪学",
];

export const nationalities = [
  "日本", "アメリカ", "韓国", "中国", "台湾", "香港",
  "東南アジア", "南アジア", "中東",
  "白人・コーカサス系", "黒人・アフリカ系", "ヒスパニック・ラテン系",
  "太平洋諸島系", "ネイティブアメリカン系", "ミックス",
  "その他",
];

export const languageOptions = [
  "日本語", "英語", "中国語", "韓国語", "フランス語", "スペイン語", "ドイツ語",
  "イタリア語", "ポルトガル語", "ロシア語", "タイ語", "ベトナム語", "インドネシア語",
  "ヒンディー語", "アラビア語", "その他",
];

export const genderOptions = [
  { value: "male", label: "男性" },
  { value: "female", label: "女性" },
  { value: "other", label: "その他" },
] as const;

export function genderLabelToRawValue(label: string): string | undefined {
  return genderOptions.find((g) => g.label === label)?.value;
}

export const gatheringCategoryOptions = [
  "ご飯",
  "カフェ・勉強",
  "スポーツ・アウトドア",
  "遊び・観光",
  "イベント参加",
  "その他",
];

export function oppositeGenderRawValue(gender: string | null): string {
  if (gender === "male") return "female";
  if (gender === "female") return "male";
  return "";
}
