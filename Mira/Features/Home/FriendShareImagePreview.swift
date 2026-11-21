import SwiftUI

struct FriendShareImagePreview: View {
    @Environment(\.dismiss) private var dismiss
    let image: Image

    var body: some View {
        VStack(spacing: 0) {
            Button("閉じる") { dismiss() }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                .padding(.horizontal)
                .accessibilityIdentifier("friendShareExactImageClose")
            image.resizable().scaledToFit()
                .accessibilityIdentifier("friendShareExactImage")
            Spacer(minLength: 0)
        }
        .background(.white)
    }
}
