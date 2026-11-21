import SwiftUI

struct FriendLevelPicker: View {
    @Environment(MiraStore.self) private var store
    let person: ImportantPersonEntity

    var body: some View {
        Picker("見せる範囲", selection: Binding(
            get: { store.friendShareLevel(for: person) },
            set: { store.setFriendShareLevel($0, for: person) }
        )) {
            ForEach(FriendShareLevel.allCases, id: \.self) { level in
                Text(level.title).tag(level)
            }
        }
        .accessibilityIdentifier("friendLevelPicker")
    }
}

struct FriendShareControls: View {
    @Environment(MiraStore.self) private var store
    @Binding var recipientID: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            Picker("見せる相手", selection: $recipientID) {
                Text("指定なし").tag(UUID?.none)
                ForEach(store.importantPeople, id: \.id) { person in
                    Text(person.name).tag(Optional(person.id))
                }
            }
            .accessibilityIdentifier("friendRecipientPicker")
            if let person = store.importantPeople.first(where: { $0.id == recipientID }) {
                FriendLevelPicker(person: person)
                if store.friendShareLevel(for: person) == .hidden {
                    Text("\(person.name)さんには見せない設定です")
                }
            }
        }
    }
}
