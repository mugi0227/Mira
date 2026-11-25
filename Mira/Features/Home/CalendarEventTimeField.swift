import SwiftUI

struct CalendarEventTimeField: View {
    let title: String
    @Binding var date: Date
    @Binding var keyboardInput: String?
    let options: CalendarDisplayOptions
    let validatesKeyboardInput: Bool

    var body: some View {
        if options.showsTimeKeyboard {
            KeyboardTimeField(
                title: title, date: $date, input: $keyboardInput, options: options,
                validatesInput: validatesKeyboardInput
            )
        } else if options.minuteInterval == 1 {
            DatePicker(title, selection: $date, displayedComponents: .hourAndMinute)
                .environment(\.locale, Locale(identifier: options.uses24HourTime ? "ja_JP@hours=h23" : "ja_JP@hours=h12"))
        } else {
            LabeledContent(title) {
                Picker("時", selection: hour) {
                    ForEach(0..<24, id: \.self) { value in
                        Text(options.uses24HourTime ? "\(value)時" : "\(value < 12 ? "午前" : "午後")\(value % 12 == 0 ? 12 : value % 12)時").tag(value)
                    }
                }
                Picker("分", selection: minute) {
                    ForEach(minutes, id: \.self) { Text(String(format: "%02d分", $0)).tag($0) }
                }
            }
        }
    }

    private var hour: Binding<Int> {
        Binding(get: { Calendar.mira.component(.hour, from: date) }, set: {
            date = date.setting(hour: $0, minute: minute.wrappedValue)
        })
    }

    private var minute: Binding<Int> {
        Binding(get: { Calendar.mira.component(.minute, from: date) }, set: {
            date = date.setting(hour: hour.wrappedValue, minute: $0)
        })
    }

    private var minutes: [Int] {
        Array(Set(stride(from: 0, to: 60, by: options.minuteInterval)).union([minute.wrappedValue])).sorted()
    }
}

private struct KeyboardTimeField: View {
    let title: String
    @Binding var date: Date
    @Binding var input: String?
    let options: CalendarDisplayOptions
    let validatesInput: Bool
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: MiraSpacing.xxs) {
            LabeledContent(title) {
                TextField("時刻（例：18:30）", text: text)
                    .accessibilityLabel(title + "時刻")
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .focused($focused)
                    .onChange(of: focused) { _, active in
                        if !active { commitInput() }
                    }
                    .onSubmit { focused = false }
            }
            if let input, !focused || validatesInput, options.timeEntered(input, on: date) == nil {
                Text("正しい時刻を入力してください")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var text: Binding<String> {
        Binding(
            get: { input ?? (focused ? DateFormatter.mira("HH:mm").string(from: date) : options.time(date)) },
            set: { input = $0 }
        )
    }

    private func commitInput() {
        guard let input, let time = options.timeEntered(input, on: date) else { return }
        date = time
        self.input = nil
    }
}
