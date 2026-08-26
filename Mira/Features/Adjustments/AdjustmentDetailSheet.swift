import SwiftUI
import UIKit

struct AdjustmentDetailSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: AdjustmentEntity
    let palette: MiraThemePalette

    @State private var showCancelConfirmation = false
    @State private var candidateToConfirm: CandidateSlotSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    statusHeader
                    candidateSection
                    sharingCard
                    if session.status == .waiting {
                        cancelButton
                    }
                }
                .padding(MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xl)
            }
            .background(palette.background)
            .navigationTitle("日程調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .confirmationDialog("この日で確定しますか？", isPresented: Binding(
                get: { candidateToConfirm != nil },
                set: { if !$0 { candidateToConfirm = nil } }
            ), titleVisibility: .visible) {
                Button("この日で確定") {
                    guard let candidate = candidateToConfirm else { return }
                    Task {
                        await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id)
                        candidateToConfirm = nil
                        dismiss()
                    }
                }
                Button("やめる", role: .cancel) { candidateToConfirm = nil }
            } message: {
                if let candidateToConfirm {
                    Text("\(candidateToConfirm.startDate.japaneseShortDate) \(candidateToConfirm.timeOfDay.title)を確定し、ほかの候補を解放します。")
                }
            }
            .confirmationDialog("調整を取りやめますか？", isPresented: $showCancelConfirmation) {
                Button("候補日をすべて解放", role: .destructive) {
                    Task {
                        await store.cancelAdjustment(session)
                        dismiss()
                    }
                }
                Button("やめる", role: .cancel) {}
            }
        }
        .tint(palette.accent)
    }

    private var statusHeader: some View {
        HStack(spacing: MiraSpacing.md) {
            if store.theme == .pixelCat {
                PixelCatView(mood: session.status == .confirmed ? .celebrating : .thinking, size: 78)
            } else {
                Image(systemName: session.status == .confirmed ? "checkmark.circle.fill" : "calendar.badge.clock")
                    .font(.system(size: 44))
                    .foregroundStyle(session.status == .confirmed ? palette.success : palette.accent)
                    .frame(width: 78)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                if let contact = session.contactName {
                    Text(contact)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(session.status == .confirmed ? palette.success : palette.warning)
            }
            Spacer(minLength: 0)
        }
        .miraCard(palette)
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Text("候補日")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)

            ForEach(session.candidates) { candidate in
                let conflicts = store.conflictMessages(for: candidate, excluding: session.id)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: MiraSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(candidate.status == .confirmed ? palette.success.opacity(0.18) : palette.adjustment)
                                .frame(width: 48, height: 48)
                            Image(systemName: candidate.status == .confirmed ? "checkmark" : "calendar")
                                .font(.headline)
                                .foregroundStyle(candidate.status == .confirmed ? palette.success : palette.primaryText)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.startDate.japaneseDayTitle)
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)
                            Text(candidate.timeOfDay.title)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        if session.status == .waiting, candidate.status == .held {
                            Button("確定") { candidateToConfirm = candidate }
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.borderedProminent)
                                .tint(palette.accent)
                                .frame(minHeight: 44)
                        } else {
                            Text(candidateStatus(candidate.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(candidate.status == .confirmed ? palette.success : palette.secondaryText)
                        }
                    }

                    if !conflicts.isEmpty, candidate.status == .held {
                        ForEach(conflicts, id: \.self) { conflict in
                            Label(conflict, systemImage: conflict.contains("余白") ? "leaf.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(conflict.contains("余白") ? palette.success : palette.warning)
                        }
                    }
                }
                .miraCard(palette, padding: MiraSpacing.sm)
            }
        }
    }

    private var sharingCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Label("送る文章", systemImage: "message")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            Text(session.generatedMessage)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .textSelection(.enabled)
            HStack(spacing: MiraSpacing.sm) {
                Button {
                    UIPasteboard.general.string = session.generatedMessage
                    store.toast = "文章をコピーしたにゃ"
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                ShareLink(item: session.generatedMessage) {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .tint(palette.accent)
        }
        .miraCard(palette)
    }

    private var cancelButton: some View {
        Button(role: .destructive) {
            showCancelConfirmation = true
        } label: {
            Label("調整を取りやめる", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(palette.critical)
    }

    private var statusText: String {
        switch session.status {
        case .draft: "下書き"
        case .waiting: "返事待ち・候補日を仮押さえ中"
        case .confirmed: "日程確定済み"
        case .cancelled: "キャンセル済み"
        }
    }

    private func candidateStatus(_ status: CandidateStatus) -> String {
        switch status {
        case .held: "仮押さえ"
        case .confirmed: "確定"
        case .released: "解放済み"
        }
    }
}
