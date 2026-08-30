# Mira Product Specification

## Product promise

空いている場所を探すのではなく、本人が必要とする休息・趣味・一人時間・大切な人との時間を先に意識し、その範囲内で予定を選べるようにする。

## Core jobs

1. 月ごとに欲しい余白を言語化する
2. 余白を大きめに配置する
3. 新しい予定が何を失わせるか理解する
4. 余白を動かしても月間目標を維持する
5. 複数の日程調整を安全に管理する
6. 数か月先の予定過多を防ぐ

## Product principles

- 余白を予定と同格に扱う
- 勝手に予定を変更しない
- 「大丈夫？」と問い返すより具体案を出す
- 大切さと身体的負荷を別軸で扱う
- AIは意味分類と表現だけに使う
- 行動履歴から性格を勝手に推測しない
- 非AI端末でも価値を欠損させない
- **Miraは予定を禁止する管理者ではなく、影響と代替案を示す秘書である**
- 基本時間、既存予定、調整中候補、守っている余白との重複は強く警告するが、本人が理解したうえで明示的に選ぶなら追加・候補化できる
- 最後の余白を失う場合も完全禁止にはせず、「余白を移す」「今回は例外」「目標を見直す」の明示的な意思決定を要求する
- ハードブロックは、終了時刻が開始時刻より前など、予定データとして成立しない状態に原則限定する

### Advisory severity

- Green: 影響が小さい。通常どおり追加できる
- Yellow: 軽い影響。短い助言を表示する
- Orange: 余白消費・目標悪化・基本時間との重なり。影響と別候補を提示する
- Red: 最後の余白・確定予定との重複など。明示的な確認を要求する
- どの段階でも、データとして成立する予定であれば最終決定権は本人に残す

## Demo scope

Implemented:
- onboarding
- margin goals and placement
- protection and relocation
- future-month provisional planning
- pending invitations
- adjustment sessions and candidate holds
- load classification and buffers
- explicit corrections
- local AI adapter and fallback
- theme skins
- notifications
- legacy import mock
- local persistence

Deferred:
- EventKit
- CloudKit
- real OCR
- store distribution
- Android
- ToDo
