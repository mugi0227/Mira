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
