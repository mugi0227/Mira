# Grill-Me Q61〜Q82 実装対応表

**ステータス:** 実装・CI検証対象  
**要求正本:** `requirements-conversational-assistant.md` / `requirements-conversational-assistant-addendum-q73-q82.md`

| Q | 決定 | 主な実装 |
|---|---|---|
| 61 | 嘘を作らないAI断り文、ガチャ、柔らかさ調整 | `ConversationAssistantService.swift`, `DeclineDraftSheet` |
| 62 | 負荷から余白量を自動推定、少なめ/ふつう/多め | `MarginRecommendationEngine.swift`, `OnboardingView`, `MarginComfortSheet` |
| 63 | Miraが複数候補を最初から提示 | `SchedulingRecommendationEngine.swift` |
| 64 | 朝/昼/夜、午前/午後、終日、詳細時刻は任意 | `DurationBucket`, `SchedulingTimeBand`, `SchedulingModeView` |
| 65 | 基本3件、2〜5件へ可変 | `recommendedCount` |
| 66 | ホームの雑入力1つ、軽い会話継続 | `MiraQuickInputBar`, `MiraStore+Conversation` |
| 67 | 案件ごとの構造化状態と会話履歴 | `ConversationCaseEntity` |
| 68 | LLMより先にローカル検索、手動指定あり | `CaseSearchEngine`, `ContextPickerSheet` |
| 69 | 通常は過去除外、明示時のみ過去検索 | `includePast`, `過去も検索` |
| 70 | 進行中/検討中/確定予定タブ | `ContextPickerSheet` |
| 71 | 雑入力・明示ボタンの両入口を同じ調整モードへ | `startManualScheduling`, `SchedulingModeView` |
| 72 | 不足項目を仮入力し、推定チップで修正 | `ConversationInterpretation`, `conditionChip` |
| 73 | 確認画面を挟まず候補付きカレンダーへ | `activeSchedulingDraft` + full-screen cover |
| 74 | 全日の時間帯ボタン、要確認候補も選択可 | `SchedulingModeView.candidateButton` |
| 75 | おすすめを初期選択、一括解除あり | `selectedRecommendationIDs`, `clearRecommendedSchedulingCandidates` |
| 76 | timeBand + durationBucketを保持 | Snapshot / SwiftData拡張 |
| 77 | 送信候補を仮押さえ、確定時に残候補解放 | `AdjustmentEntity`, `confirmCandidate` |
| 78 | 日付・時間帯だけでも確定、詳細時刻は後から | `exactTimeKnown`, `timeDescription`, change preview |
| 79 | 会話履歴を案件ごとに保存、モデルへは直近のみ | `ConversationCaseEntity.turns` |
| 80 | 自然言語変更はbefore→afterプレビュー後に保存 | `ChangePreviewSheet` |
| 81 | LINE等の文章をそのまま貼って解析 | `ConversationAssistantService` |
| 82 | 裏で再計算、変更は完成案を確認後に適用 | `RebalanceEngine`, `RebalanceProposalSheet` |

## テスト

- `ConversationalAssistantTests.swift`
  - コピペ誘い解析
  - 曖昧時だけ質問
  - 過去検索の明示制御
  - 粗い時間帯データの永続化
- `SchedulingRecommendationTests.swift`
  - 候補数2〜5件
  - 仮押さえ・基本時間を禁止せず警告
- `MarginRecommendationTests.swift`
  - 負荷増で必要余白が増える
  - 少なめ ≤ ふつう ≤ 多め
- `GrillMeFlowUITests.swift`
  - 雑入力から調整カレンダーへ遷移
  - 案件ピッカーのカテゴリタブと過去検索

## 非同期AIの責務境界

Foundation Modelsは以下だけを担当する。

- 意図分類
- 情報抽出
- 所要時間・時間帯の仮入力
- 少数の検索候補からの意味照合
- 自然文生成

以下は決定論的なアプリコードが担当する。

- ローカル検索
- 空き・重複・基本時間判定
- 余白保護
- 負荷と目標計算
- 候補ランキング
- 保存・更新

## デザインアセット

生成画像スキンは `roadmap-generated-skins.md` に従い、機能完成後のCodex制作フェーズへ延期する。
