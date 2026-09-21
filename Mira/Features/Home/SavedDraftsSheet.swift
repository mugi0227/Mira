import SwiftUI

struct SavedDraftsSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let onResume: (UUID) -> Void

    @State private var draftToDelete: SavedMiraDraft?

    var body: some View {
        NavigationStack {
            List {
                if store.savedDrafts.isEmpty {
                    ContentUnavailableView("下書きはありません", systemImage: "tray", description: Text("途中で閉じた入力や日程候補がここに残ります。"))
                } else {
                    Section {
                        ForEach(store.savedDrafts) { draft in
                            Button {
                                onResume(draft.id)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(draft.content.title).font(.headline).foregroundStyle(palette.primaryText)
                                    Text(draft.content.nextStep).font(.subheadline).foregroundStyle(palette.secondaryText)
                                }
                                .frame(minHeight: 52, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .swipeActions {
                                Button("削除", role: .destructive) { draftToDelete = draft }
                            }
                            .contextMenu {
                                Button("下書きを削除", role: .destructive) { draftToDelete = draft }
                            }
                        }
                    } footer: {
                        Text("ここに残すだけでは、予定の追加や相手への送信は行いません。不要な下書きは左へスワイプして削除できます。")
                    }
                }
            }
            .navigationTitle("続きから")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("下書きを削除しますか？", isPresented: Binding(
                get: { draftToDelete != nil },
                set: { if !$0 { draftToDelete = nil } }
            )) {
                Button("削除", role: .destructive) {
                    if let draftToDelete { store.discardSavedDraft(id: draftToDelete.id) }
                    draftToDelete = nil
                }
                Button("続ける", role: .cancel) { draftToDelete = nil }
            } message: {
                Text("登録済みの予定や日程調整は変わりません。")
            }
        }
        .tint(palette.accent)
    }
}
