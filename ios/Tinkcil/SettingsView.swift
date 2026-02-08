//
//  SettingsView.swift
//  Tinkcil
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    let bleManager: BLEManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ConfigurationView(bleManager: bleManager)
                    .tabItem {
                        Label(String(localized: "settings_tab"), systemImage: "slider.horizontal.3")
                    }
                    .tag(0)

                DiagnosticsView(bleManager: bleManager)
                    .tabItem {
                        Label(String(localized: "info_tab"), systemImage: "info.circle")
                    }
                    .tag(1)
            }
            .navigationTitle(selectedTab == 0 ? String(localized: "settings_tab") : String(localized: "device_info_title"))
            .navigationBarTitleDisplayMode(.inline)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "button_done")) {
                        hapticLight()
                        dismiss()
                    }
                }
            }
        }
    }

    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Configuration View

struct ConfigurationView: View {
    let bleManager: BLEManager
    @State private var settings: [Int: UInt16] = [:]
    @State private var isLoading = false
    @State private var saveInProgress = false
    
    var body: some View {
        List {
            Section(String(localized: "section_temperature")) {
                SettingRow(
                    label: String(localized: "setting_soldering_temp"),
                    value: Binding(
                        get: { settings[0] ?? 320 },
                        set: { settings[0] = $0 }
                    ),
                    range: 10...450,
                    step: 5,
                    unit: "°C",
                    onChange: { bleManager.writeSetting(index: 0, value: $0) }
                )

                SettingRow(
                    label: String(localized: "setting_sleep_temp"),
                    value: Binding(
                        get: { settings[1] ?? 150 },
                        set: { settings[1] = $0 }
                    ),
                    range: 10...450,
                    step: 5,
                    unit: "°C",
                    onChange: { bleManager.writeSetting(index: 1, value: $0) }
                )

                SettingRow(
                    label: String(localized: "setting_boost_temp"),
                    value: Binding(
                        get: { settings[22] ?? 420 },
                        set: { settings[22] = $0 }
                    ),
                    range: 10...450,
                    step: 10,
                    unit: "°C",
                    onChange: { bleManager.writeSetting(index: 22, value: $0) }
                )
            }

            Section(String(localized: "section_timers")) {
                SettingRow(
                    label: String(localized: "setting_sleep_time"),
                    value: Binding(
                        get: { settings[2] ?? 1 },
                        set: { settings[2] = $0 }
                    ),
                    range: 0...15,
                    step: 1,
                    unit: "min",
                    onChange: { bleManager.writeSetting(index: 2, value: $0) }
                )

                SettingRow(
                    label: String(localized: "setting_shutdown_time"),
                    value: Binding(
                        get: { settings[11] ?? 10 },
                        set: { settings[11] = $0 }
                    ),
                    range: 0...60,
                    step: 1,
                    unit: "min",
                    onChange: { bleManager.writeSetting(index: 11, value: $0) }
                )
            }

            Section(String(localized: "section_power")) {
                SettingRow(
                    label: String(localized: "setting_power_limit"),
                    value: Binding(
                        get: { settings[24] ?? 65 },
                        set: { settings[24] = $0 }
                    ),
                    range: 0...180,
                    step: 5,
                    unit: "W",
                    onChange: { bleManager.writeSetting(index: 24, value: $0) }
                )
            }

            Section(String(localized: "section_display")) {
                PickerSettingRow(
                    label: String(localized: "setting_orientation"),
                    value: Binding(
                        get: { settings[6] ?? 2 },
                        set: { settings[6] = $0 }
                    ),
                    options: [
                        (0, String(localized: "option_right")),
                        (1, String(localized: "option_left")),
                        (2, String(localized: "option_auto"))
                    ],
                    onChange: { bleManager.writeSetting(index: 6, value: $0) }
                )

                SettingRow(
                    label: String(localized: "setting_brightness"),
                    value: Binding(
                        get: { settings[34] ?? 51 },
                        set: { settings[34] = $0 }
                    ),
                    range: 1...101,
                    step: 25,
                    unit: "%",
                    onChange: { bleManager.writeSetting(index: 34, value: $0) }
                )

                ToggleSettingRow(
                    label: String(localized: "setting_invert_display"),
                    value: Binding(
                        get: { settings[33] == 1 },
                        set: { settings[33] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 33, value: $0 ? 1 : 0) }
                )

                ToggleSettingRow(
                    label: String(localized: "setting_detailed_idle"),
                    value: Binding(
                        get: { settings[13] == 1 },
                        set: { settings[13] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 13, value: $0 ? 1 : 0) }
                )

                ToggleSettingRow(
                    label: String(localized: "setting_detailed_soldering"),
                    value: Binding(
                        get: { settings[14] == 1 },
                        set: { settings[14] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 14, value: $0 ? 1 : 0) }
                )
            }

            Section(String(localized: "section_sensors")) {
                SettingRow(
                    label: String(localized: "setting_motion_sensitivity"),
                    value: Binding(
                        get: { settings[7] ?? 6 },
                        set: { settings[7] = $0 }
                    ),
                    range: 0...9,
                    step: 1,
                    unit: "",
                    onChange: { bleManager.writeSetting(index: 7, value: $0) }
                )

                SettingRow(
                    label: String(localized: "setting_hall_sensitivity"),
                    value: Binding(
                        get: { settings[28] ?? 7 },
                        set: { settings[28] = $0 }
                    ),
                    range: 0...9,
                    step: 1,
                    unit: "",
                    onChange: { bleManager.writeSetting(index: 28, value: $0) }
                )
            }

            Section(String(localized: "section_controls")) {
                PickerSettingRow(
                    label: String(localized: "setting_locking_mode"),
                    value: Binding(
                        get: { settings[17] ?? 0 },
                        set: { settings[17] = $0 }
                    ),
                    options: [
                        (0, String(localized: "option_off")),
                        (1, String(localized: "option_boost_only")),
                        (2, String(localized: "option_full"))
                    ],
                    onChange: { bleManager.writeSetting(index: 17, value: $0) }
                )

                ToggleSettingRow(
                    label: String(localized: "setting_reverse_buttons"),
                    value: Binding(
                        get: { settings[25] == 1 },
                        set: { settings[25] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 25, value: $0 ? 1 : 0) }
                )

                SettingRow(
                    label: String(localized: "setting_short_press_step"),
                    value: Binding(
                        get: { settings[27] ?? 1 },
                        set: { settings[27] = $0 }
                    ),
                    range: 1...25,
                    step: 1,
                    unit: "°C",
                    onChange: { bleManager.writeSetting(index: 27, value: $0) }
                )

                SettingRow(
                    label: String(localized: "setting_long_press_step"),
                    value: Binding(
                        get: { settings[26] ?? 10 },
                        set: { settings[26] = $0 }
                    ),
                    range: 5...50,
                    step: 5,
                    unit: "°C",
                    onChange: { bleManager.writeSetting(index: 26, value: $0) }
                )
            }
            
            Section {
                Button {
                    saveSettings()
                } label: {
                    HStack {
                        Spacer()
                        if saveInProgress {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(String(localized: "button_save_to_device"))
                        Spacer()
                    }
                }
                .disabled(saveInProgress)
                .accessibilityLabel(saveInProgress ? String(localized: "saving_settings") : String(localized: "save_settings_hint"))
                .accessibilityHint("Saves all settings to persist across device restarts")
            } footer: {
                Text(String(localized: "settings_footer_message"))
            }
        }
        .overlay {
            if isLoading {
                ProgressView(String(localized: "loading_settings"))
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Loading device settings")
            }
        }
        .task {
            // Pre-populate from cache first for instant display
            let settingsToLoad: [UInt16] = [0, 1, 2, 6, 7, 11, 13, 14, 17, 22, 24, 25, 26, 27, 28, 33, 34]
            for index in settingsToLoad {
                if let cached = bleManager.settingsCache.get(index) {
                    settings[Int(index)] = cached
                }
            }

            // Then load from device in background
            await loadSettings()
        }
    }

    private func saveSettings() {
        saveInProgress = true
        hapticLight()
        bleManager.saveSettings()

        // Wait for a reasonable time for the write operation
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                hapticSuccess()
                saveInProgress = false
            }
        }
    }

    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func hapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func loadSettings() async {
        // Load commonly used settings (will use cache if available)
        let settingsToLoad: [UInt16] = [0, 1, 2, 6, 7, 11, 13, 14, 17, 22, 24, 25, 26, 27, 28, 33, 34]

        isLoading = true

        // Check if we're still connected before loading
        guard bleManager.connectionState.isConnected else {
            isLoading = false
            return
        }

        await withTaskGroup(of: (Int, UInt16?).self) { group in
            for index in settingsToLoad {
                group.addTask { @MainActor in
                    // Check connection state before each read
                    guard bleManager.connectionState.isConnected else {
                        return (Int(index), nil)
                    }

                    return await withCheckedContinuation { (continuation: CheckedContinuation<(Int, UInt16?), Never>) in
                        bleManager.readSetting(index: index) { value in
                            continuation.resume(returning: (Int(index), value))
                        }
                    }
                }
            }

            for await (index, value) in group {
                if let value = value {
                    settings[index] = value
                }
            }
        }

        isLoading = false
    }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    let bleManager: BLEManager
    
    var body: some View {
        List {
            Section(String(localized: "section_device_info")) {
                InfoRow(label: String(localized: "info_device_name"), value: bleManager.deviceName)
                InfoRow(label: String(localized: "info_firmware"), value: bleManager.firmwareVersion.isEmpty ? String(localized: "common_unknown") : bleManager.firmwareVersion)
                InfoRow(label: String(localized: "info_build_id"), value: bleManager.buildID.isEmpty ? String(localized: "common_unknown") : bleManager.buildID)
                InfoRow(label: String(localized: "info_serial_number"), value: bleManager.deviceSerial.isEmpty ? String(localized: "common_unknown") : bleManager.deviceSerial)
            }

            Section(String(localized: "section_current_status")) {
                InfoRow(label: String(localized: "info_temperature"), value: "\(bleManager.liveData.liveTemp)°C")
                InfoRow(label: String(localized: "info_setpoint"), value: "\(bleManager.liveData.setpoint)°C")
                InfoRow(label: String(localized: "info_max_temperature"), value: "\(bleManager.liveData.maxTemp)°C")
                InfoRow(label: String(localized: "info_operating_mode"), value: bleManager.liveData.mode?.displayName ?? String(localized: "common_unknown"))
            }

            Section(String(localized: "section_power")) {
                InfoRow(label: String(localized: "info_voltage"), value: String(format: "%.1f V", bleManager.liveData.voltage))
                InfoRow(label: String(localized: "info_wattage"), value: String(format: "%.1f W", bleManager.liveData.watts))
                InfoRow(label: String(localized: "info_power_level"), value: "\(bleManager.liveData.powerPercent)%")
                InfoRow(label: String(localized: "info_power_source"), value: bleManager.liveData.power?.displayName ?? String(localized: "common_unknown"))
            }

            Section(String(localized: "section_diagnostics")) {
                InfoRow(label: String(localized: "info_handle_temp"), value: String(format: "%.1f°C", bleManager.liveData.handleTempC))
                InfoRow(label: String(localized: "info_tip_resistance"), value: String(format: "%.2f Ω", bleManager.liveData.resistance))
                InfoRow(label: String(localized: "info_raw_tip"), value: "\(bleManager.liveData.rawTip) μV")
                InfoRow(label: String(localized: "info_hall_sensor"), value: "\(bleManager.liveData.hallSensor)")
                InfoRow(label: String(localized: "info_uptime"), value: formatUptime(bleManager.liveData.uptime))
                InfoRow(label: String(localized: "info_last_movement"), value: formatTimeAgo(bleManager.liveData.uptime, lastMovement: bleManager.liveData.lastMovement))
            }
            
            Section {
                Button(role: .destructive) {
                    hapticWarning()
                    bleManager.disconnect()
                } label: {
                    HStack {
                        Spacer()
                        Text(String(localized: "button_disconnect"))
                        Spacer()
                    }
                }
                .accessibilityLabel("Disconnect from device")
                .accessibilityHint("Closes the Bluetooth connection to your soldering iron")
            }
        }
    }
    
    private func formatUptime(_ deciseconds: UInt32) -> String {
        let totalSeconds = deciseconds / 10
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    private func formatTimeAgo(_ uptime: UInt32, lastMovement: UInt32) -> String {
        let uptimeSeconds = uptime / 10
        let lastMovementSeconds = lastMovement / 10
        
        if uptimeSeconds < lastMovementSeconds {
            return "just now"
        }
        
        let secondsAgo = uptimeSeconds - lastMovementSeconds
        if secondsAgo < 60 {
            return "\(secondsAgo)s ago"
        } else if secondsAgo < 3600 {
            let minutes = secondsAgo / 60
            return "\(minutes)m ago"
        } else {
            let hours = secondsAgo / 3600
            let minutes = (secondsAgo % 3600) / 60
            return "\(hours)h \(minutes)m ago"
        }
    }

    private func hapticWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Setting Row Components

struct SettingRow: View {
    let label: String
    @Binding var value: UInt16
    let range: ClosedRange<UInt16>
    let step: UInt16
    let unit: String
    let onChange: (UInt16) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value) \(unit)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityHidden(true)

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = UInt16($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step),
                onEditingChanged: { editing in
                    if editing {
                        hapticSelection()
                    } else {
                        hapticLight()
                        onChange(value)
                    }
                }
            )
            .accessibilityLabel(label)
            .accessibilityValue("\(value) \(unit)")
            .accessibilityHint("Adjust using the slider. Range is \(range.lowerBound) to \(range.upperBound) \(unit)")
        }
        .accessibilityElement(children: .contain)
    }

    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

struct ToggleSettingRow: View {
    let label: String
    @Binding var value: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(label, isOn: Binding(
            get: { value },
            set: { newValue in
                hapticLight()
                value = newValue
                onChange(newValue)
            }
        ))
        .accessibilityLabel(label)
        .accessibilityValue(value ? "On" : "Off")
        .accessibilityHint("Double tap to toggle")
    }

    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

struct PickerSettingRow: View {
    let label: String
    @Binding var value: UInt16
    let options: [(UInt16, String)]
    let onChange: (UInt16) -> Void

    var body: some View {
        Picker(label, selection: Binding(
            get: { value },
            set: { newValue in
                hapticSelection()
                value = newValue
                onChange(newValue)
            }
        )) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .accessibilityLabel(label)
        .accessibilityValue(options.first(where: { $0.0 == value })?.1 ?? "")
        .accessibilityHint("Select an option from the list")
    }

    private func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
