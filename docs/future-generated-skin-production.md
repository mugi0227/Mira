# Mira 生成画像スキン制作 — 後続フェーズ

**ステータス:** 実装後に別タスクとして実施  
**担当想定:** Codex / Work等の長時間ファイル制作ワークフロー  
**本PRの扱い:** UI・状態・アセット差替え境界まで維持し、生成画像そのものは追加しない

## 目的

Miraの機能実装と動作検証を先に完成させた後、みらのが使いたくなる着せ替え品質へ引き上げる。

## 制作候補

- Pixel Catの統一キャラクターセット
  - idle
  - relaxed
  - thinking
  - warning
  - tired
  - sleeping
  - happy
  - celebrating
- Soft Minimal向けの静かなオンボーディング挿絵
- 空状態イラスト
- スキン別の背景パターン・小装飾
- 猫スキンの複数バリエーション

## 制作要件

- 同一キャラクターとして認識できる一貫した形状・配色
- 小サイズでも表情を判別可能
- 透過背景
- Light / Dark双方で使用可能
- ナビゲーションや操作アイコンの代替にはせず、案内・警告・成功等の補助表現として使う
- 画像内へUI文字を焼き込まない
- 標準のホワイトバランスはニュートラルな昼光相当

## 推奨ワークフロー

1. 3系統程度のスキンコンセプトを生成する。
2. 実際のMira画面へ合成したモックで比較する。
3. 1系統を選び、状態差分をまとめて生成する。
4. 背景透過・トリミング・サイズ統一を行う。
5. `Assets.xcassets`へ命名規則付きで配置する。
6. `PixelCatView`の描画実装をアセット優先・現行ベクター描画フォールバックへ変更する。
7. Simulatorスクリーンショットで視認性・邪魔にならないことを確認する。

## 命名案

- `skin_pixel_cat_idle`
- `skin_pixel_cat_relaxed`
- `skin_pixel_cat_thinking`
- `skin_pixel_cat_warning`
- `skin_pixel_cat_tired`
- `skin_pixel_cat_sleeping`
- `skin_pixel_cat_happy`
- `skin_pixel_cat_celebrating`

## 完了条件

- 主要5画面でアセットを適用したSimulatorスクリーンショットがある
- Dynamic Type時にも情報を隠さない
- 猫表示OFFまたはSoft Minimalでも全機能が成立する
- 生成画像がなくても現行のプログラム描画へ安全にフォールバックする
