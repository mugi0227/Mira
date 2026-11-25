import SwiftUI

struct CalendarDisplaySettingsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette
    @State private var confirmDeletion = false

    var body: some View {
        @Bindable var store = store
        let options = $store.calendarDisplayOptions

        Form {
            Section("外観") {
                preview
                Toggle("時刻の表示", isOn: options.showsStartTime)
                    .accessibilityIdentifier("calendarShowsStartTime")
                Toggle("時間予定の区別", isOn: options.distinguishesTimedEvents)
                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    Text("ラベルの配色")
                    HStack(spacing: MiraSpacing.xs) {
                        ForEach(CalendarDisplayOptions.LabelStyle.allCases, id: \.self) { style in
                            styleCard(style)
                        }
                    }
                }
                .padding(.vertical, MiraSpacing.xs)
            }
            Section("文字") {
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    Text("文字の太さ")
                    Picker("文字の太さ", selection: options.textWeight) {
                        ForEach(CalendarDisplayOptions.TextWeight.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    Text("文字の大きさ")
                    Picker("文字の大きさ", selection: options.textSize) {
                        ForEach(CalendarDisplayOptions.TextSize.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            Section("カレンダーのめくりかた") {
                pagingRow("横スクロール（左右に月めくり）", vertical: false)
                pagingRow("縦スクロール（月の見出しを上下に）", vertical: true)
            }
            Section("予定リスト") {
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    Text("リスト表示")
                    Picker("リスト表示", selection: options.alwaysShowsAgenda) {
                        Text("タップ時に表示").tag(false)
                        Text("常に表示").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Picker("リストの高さ", selection: options.agendaHeight) {
                    ForEach(1...8, id: \.self) { Text("予定\($0)件分").tag($0) }
                }
                Picker("メモの表示行数", selection: options.memoLines) {
                    ForEach(1...5, id: \.self) { Text("\($0)行").tag($0) }
                }
            }
            Section {
                Toggle("24時間表示", isOn: options.uses24HourTime)
                Picker("週の開始曜日", selection: Binding(
                    get: { store.weekStartDay },
                    set: { store.setWeekStartDay($0) }
                )) {
                    ForEach(WeekStartDay.allCases.sorted { $0.calendarFirstWeekday < $1.calendarFirstWeekday }) { value in
                        Text(value.title).tag(value)
                    }
                }
                Toggle("週番号の表示", isOn: options.showsWeekNumbers)
                    .accessibilityIdentifier("calendarShowsWeekNumbers")
                Toggle("祝日の表示", isOn: Binding(
                    get: { store.showsPublicHolidays },
                    set: { store.setShowsPublicHolidays($0) }
                ))
                .accessibilityIdentifier("calendarShowsPublicHolidays")
                Toggle("六曜の表示", isOn: options.showsRokuyo)
                    .accessibilityIdentifier("calendarShowsRokuyo")
                NavigationLink {
                    Form {
                        ForEach(1...7, id: \.self) { day in
                            Toggle(WeekStartDay.symbols[day - 1] + "曜日", isOn: Binding(
                                get: { store.calendarDisplayOptions.daysOff.contains(day) },
                                set: { selected in
                                    if selected { store.calendarDisplayOptions.daysOff.insert(day) }
                                    else { store.calendarDisplayOptions.daysOff.remove(day) }
                                }
                            ))
                        }
                    }
                    .navigationTitle("休日の選択")
                    .miraFormStyle(palette)
                } label: {
                    LabeledContent("休日の選択") {
                        let selected = store.calendarDisplayOptions.daysOff.sorted().map { WeekStartDay.symbols[$0 - 1] }
                        Text(selected.isEmpty ? "なし" : selected.joined(separator: "・"))
                    }
                }
            } footer: {
                Text("日本の祝日はMiraが計算します。iPhoneカレンダーへの接続は不要です。休日の選択はカレンダーの色だけを変え、仕事・学校の時間には影響しません。")
            }
            Section {
                NavigationLink("デフォルトカレンダーの選択") { defaultCalendar }
                NavigationLink("カレンダーの並び順") { calendarOrder }
                Picker("時刻の選択単位", selection: options.minuteInterval) {
                    ForEach([1, 5, 10, 15, 30], id: \.self) { Text("\($0)分").tag($0) }
                }
                Picker("新規予定の長さ", selection: options.newEventMinutes) {
                    ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { Text("\($0)分").tag($0) }
                }
                Toggle("時刻設定のキーボード表示", isOn: options.showsTimeKeyboard)
                Toggle("常に終日予定にする", isOn: options.defaultsToAllDay)
            }
            Section("時刻") {
                Picker("1日の開始時刻", selection: options.dayStartHour) {
                    ForEach(0..<store.calendarDisplayOptions.dayEndHour, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                Picker("1日の終了時刻", selection: options.dayEndHour) {
                    ForEach((store.calendarDisplayOptions.dayStartHour + 1)...24, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
            }
            Section {
                Button("重複イベントを削除", role: .destructive) { confirmDeletion = true }
            } footer: {
                Text("Miraに保存した同じ内容の予定を1件だけ残します。iPhoneカレンダーの予定は削除しません。")
            }
        }
        .navigationTitle("一般設定")
        .navigationBarTitleDisplayMode(.inline)
        .miraFormStyle(palette)
        .confirmationDialog("重複イベントを削除しますか？", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("重複イベントを削除", role: .destructive) { store.deleteDuplicateCalendarItems() }
        }
    }

    private var defaultCalendar: some View {
        Form {
            if store.deviceCalendarService.enabled && store.deviceCalendarService.hasAccess {
                Section {
                    DeviceCalendarDestinationPicker(title: "予定を書き出す先")
                } footer: {
                    Text("Miraの予定をiPhoneカレンダーへ保存するときの書き出し先です。予定は自動で書き出されません。")
                }
            } else {
                NavigationLink("iPhoneカレンダーと接続") { DeviceCalendarSettingsView(palette: palette) }
            }
        }
        .navigationTitle("デフォルトカレンダーの選択")
        .miraFormStyle(palette)
    }

    private var calendarOrder: some View {
        Form {
            if store.deviceCalendarService.enabled && store.deviceCalendarService.hasAccess {
                let service = store.deviceCalendarService
                ForEach(service.calendars) { Text($0.title) }
                    .onMove { offsets, destination in
                        var calendars = service.calendars.map(\.id)
                        calendars.move(fromOffsets: offsets, toOffset: destination)
                        service.orderIDs = calendars
                    }
            } else {
                NavigationLink("iPhoneカレンダーと接続") { DeviceCalendarSettingsView(palette: palette) }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("カレンダーの並び順")
        .miraFormStyle(palette)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 24 { return store.calendarDisplayOptions.uses24HourTime ? "24:00" : "翌日 午前0:00" }
        return store.calendarDisplayOptions.time(store.now.setting(hour: hour))
    }

    private func pagingRow(_ title: String, vertical: Bool) -> some View {
        Button {
            store.calendarDisplayOptions.pagesVertically = vertical
        } label: {
            HStack {
                Text(title)
                Spacer()
                if store.calendarDisplayOptions.pagesVertically == vertical {
                    Image(systemName: "checkmark").foregroundStyle(palette.accent)
                }
            }
        }
        .foregroundStyle(palette.primaryText)
        .accessibilityAddTraits(store.calendarDisplayOptions.pagesVertically == vertical ? .isSelected : [])
    }

    private func styleCard(_ style: CalendarDisplayOptions.LabelStyle) -> some View {
        var options = store.calendarDisplayOptions
        let selected = style == options.labelStyle
        options.labelStyle = style
        return Button {
            store.calendarDisplayOptions.labelStyle = style
        } label: {
            VStack(spacing: 4) {
                sampleChip("打ち合わせ", tag: .skyDeep, options: options)
                sampleChip("打ち合わせ", tag: .pinkDeep, options: options)
                Text(style.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.primaryText)
                    .minimumScaleFactor(0.7)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(selected ? palette.accent : palette.secondaryText)
            }
            .padding(5)
            .frame(maxWidth: .infinity)
            .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? palette.accent : palette.cardBorder)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var preview: some View {
        let options = store.calendarDisplayOptions
        let start = Calendar.mira.date(byAdding: .day, value: -((Calendar.mira.component(.weekday, from: store.now) - store.weekStartDay.calendarFirstWeekday + 7) % 7), to: store.now) ?? store.now
        return HStack(spacing: 0) {
            if options.showsWeekNumbers {
                Text("\(CalendarDisplayOptions.weekNumber(for: start, startingOn: store.weekStartDay))")
                    .font(.system(size: 9))
                    .foregroundStyle(palette.secondaryText)
                    .padding(.trailing, 3)
            }
            ForEach(0..<7, id: \.self) { index in
                let date = start.addingDays(index)
                let weekday = Calendar.mira.component(.weekday, from: date)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Calendar.mira.component(.day, from: date))")
                        .font(.system(size: 13 + CGFloat(options.textSize.rawValue), weight: options.textWeight.fontWeight))
                        .foregroundStyle(options.daysOff.contains(weekday) ? palette.critical : palette.primaryText)
                    if options.showsRokuyo, let label = CalendarDisplayOptions.rokuyo(for: date) {
                        Text(label).font(.system(size: 7)).foregroundStyle(palette.secondaryText)
                    }
                    if index == 1 { sampleChip("定例", tag: .pinkDeep, options: options) }
                    if index == 3 || index == 4 {
                        let time = options.showsStartTime ? options.time(date.setting(hour: index == 3 ? 12 : 18)) + " " : ""
                        if index == 4 { sampleChip("旅行", tag: .greenDeep, options: options) }
                        sampleChip(time + (index == 3 ? "ランチ" : "ジム"), tag: .skyDeep, options: options, isTimed: true)
                    }
                    if index == 5 && store.showsPublicHolidays {
                        Text("祝日").font(.system(size: 8)).foregroundStyle(palette.critical)
                    }
                    Spacer(minLength: 0)
                }
                .padding(2)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
                .overlay(alignment: .trailing) {
                    if index < 6 { Rectangle().fill(palette.cardBorder).frame(width: 0.5) }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func sampleChip(_ title: String, tag: EventColorTag, options: CalendarDisplayOptions, isTimed: Bool = false) -> some View {
        let style = CalendarLabelAppearance(options: options, palette: palette, tag: tag, isTimed: isTimed)
        return Text(title)
            .font(.system(size: 9 + CGFloat(options.textSize.rawValue), weight: options.textWeight.fontWeight))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity)
            .foregroundStyle(style.foreground)
            .background(style.background, in: RoundedRectangle(cornerRadius: 3))
    }
}
