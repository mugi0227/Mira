import SwiftUI

struct FriendLevelPicker: View {
    @Environment(MiraStore.self) private var store
    let person: ImportantPersonEntity
    let palette: MiraThemePalette

    var body: some View {
        HStack {
            Text("見せる範囲").foregroundStyle(palette.secondaryText)
            Spacer(minLength: MiraSpacing.xs)
            Picker("見せる範囲", selection: Binding(
                get: { store.friendShareLevel(for: person) },
                set: { store.setFriendShareLevel($0, for: person) }
            )) {
                ForEach(FriendShareLevel.allCases, id: \.self) { level in
                    Text(level.title).tag(level)
                }
            }
            .accessibilityIdentifier("friendLevelPicker")
            .labelsHidden()
            .tint(palette.accent)
        }
        .font(.subheadline)
    }
}

struct FriendShareControls: View {
    @Environment(MiraStore.self) private var store
    @Binding var recipientID: UUID?
    let palette: MiraThemePalette

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("見せる相手").foregroundStyle(palette.secondaryText)
                Spacer(minLength: MiraSpacing.xs)
                Picker("見せる相手", selection: $recipientID) {
                    Text("指定なし").tag(UUID?.none)
                    ForEach(store.importantPeople, id: \.id) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                }
                .accessibilityIdentifier("friendRecipientPicker")
                .labelsHidden()
                .tint(palette.accent)
            }
            .font(.subheadline)
            if let person = store.importantPeople.first(where: { $0.id == recipientID }) {
                FriendLevelPicker(person: person, palette: palette)
                if store.friendShareLevel(for: person) == .hidden {
                    Text("\(person.name)さんには見せない設定です")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
    }
}
