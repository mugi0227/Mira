import SwiftUI

struct ImportantPeopleSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var name = ""
    @State private var hasTarget = false
    @State private var monthlyTarget = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("追加") {
                    TextField("名前や呼び名", text: $name)
                    Toggle("この人との月間目標を設定", isOn: $hasTarget)
                    if hasTarget {
                        Stepper("月 \(monthlyTarget)回", value: $monthlyTarget, in: 1...10)
                    }
                    Button {
                        store.addImportantPerson(name: name, monthlyTarget: hasTarget ? monthlyTarget : nil)
                        name = ""
                        hasTarget = false
                        monthlyTarget = 1
                    } label: {
                        Label("追加", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(palette.surface)

                Section("登録済み") {
                    if store.importantPeople.isEmpty {
                        Text("まだ登録されていません。予定へのタグ付けは、人物登録なしでもできます。")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    } else {
                        ForEach(store.importantPeople, id: \.id) { person in
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(palette.important)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                    if person.targetEnabled, let target = person.monthlyTarget {
                                        Text("月 \(target)回")
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    store.removeImportantPerson(id: person.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("\(person.name)を削除")
                            }
                        }
                    }
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .miraFormStyle(palette)
            .miraScreenBackground(palette)
            .navigationTitle("大切な人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
        }
        .tint(palette.accent)
    }
}
