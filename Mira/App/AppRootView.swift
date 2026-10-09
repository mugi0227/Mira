import SwiftUI
import EventKit

extension Notification.Name {
    static let miraRetryStorage = Notification.Name("mira.retryStorage")
}

struct AppRootView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = MiraThemePalette(kind: store.theme, colorScheme: colorScheme)

        ZStack {
            MiraScreenBackground(palette: palette)

            if store.isEmergencyStorage {
                VStack(spacing: MiraSpacing.lg) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("保存済みのデータを開けませんでした").font(.title2.bold())
                    Text("予定を失わないよう、データはそのまま残しています。空き容量を確認し、もう一度読み込んでください。")
                    Button("もう一度読み込む") {
                        NotificationCenter.default.post(name: .miraRetryStorage, object: nil)
                    }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                }.padding(MiraSpacing.lg)
            } else if !store.isReady {
                VStack(spacing: MiraSpacing.md) {
                    PixelCatView(mood: .thinking, size: 84)
                    ProgressView("余白を準備中…")
                        .tint(palette.accent)
                        .foregroundStyle(palette.primaryText)
                }
            } else if !store.onboardingCompleted {
                OnboardingView(palette: palette)
            } else {
                MainTabView(palette: palette)
            }
        }
        .task {
            if !store.isReady && !store.isEmergencyStorage { await store.bootstrap() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && store.isReady {
                Task { await store.refreshDeviceCalendar(); await store.reconcileReminders() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            if store.isReady { Task { await store.refreshDeviceCalendar() } }
        }
        .safeAreaInset(edge: .bottom) {
            if let issue = store.persistenceIssue ?? store.draftPersistenceIssue {
                VStack(alignment: .leading, spacing: 8) {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                    if store.draftPersistenceIssue != nil {
                        Button("下書きの保存を再試行") { store.persistDraftArchive() }
                            .frame(minHeight: 44)
                    }
                    if store.persistenceIssue != nil {
                        Button("この案内を閉じる") { store.persistenceIssue = nil }
                            .frame(minHeight: 44)
                    }
                }.padding().background(palette.surface)
            } else if let undo = store.undoEntry {
                HStack(spacing: MiraSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.success)
                        .accessibilityHidden(true)
                    Text("\(undo.title)を保存しました")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button("取り消す") { Task { await store.undoLastCalendarMutation() } }
                        .font(.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                    Button { store.undoEntry = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .foregroundStyle(palette.secondaryText)
                        .accessibilityLabel("取り消しの案内を閉じる")
                }
                .padding(.leading, MiraSpacing.md)
                .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                        .strokeBorder(palette.primaryText.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: palette.shadow, radius: 14, y: 4)
                .padding(.horizontal, MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undo.after) {
                    // Keep the way back visible long enough to notice, then step aside.
                    do { try await Task.sleep(for: .seconds(10)) } catch { return }
                    if store.undoEntry?.after == undo.after { store.undoEntry = nil }
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, MiraSpacing.md)
                    .padding(.vertical, MiraSpacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: palette.shadow, radius: 12, y: 5)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        do { try await Task.sleep(for: .seconds(2.6)) }
                        catch { return }
                        guard store.toast == toast else { return }
                        withAnimation(reduceMotion ? nil : MiraMotion.standard) { store.toast = nil }
                    }
            }
        }
        .animation(reduceMotion ? nil : MiraMotion.standard, value: store.onboardingCompleted)
        .preferredColorScheme(nil)
    }
}
