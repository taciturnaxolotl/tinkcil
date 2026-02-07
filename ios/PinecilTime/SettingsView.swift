//
//  SettingsView.swift
//  PinecilTime
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
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .tag(0)
                
                DiagnosticsView(bleManager: bleManager)
                    .tabItem {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tag(1)
            }
            .navigationTitle(selectedTab == 0 ? "Settings" : "Device Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
            Section("Temperature") {
                SettingRow(
                    label: "Soldering Temp",
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
                    label: "Sleep Temp",
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
                    label: "Boost Temp",
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
            
            Section("Timers") {
                SettingRow(
                    label: "Sleep Time",
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
                    label: "Shutdown Time",
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
            
            Section("Power") {
                SettingRow(
                    label: "Power Limit",
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
            
            Section("Display") {
                PickerSettingRow(
                    label: "Orientation",
                    value: Binding(
                        get: { settings[6] ?? 2 },
                        set: { settings[6] = $0 }
                    ),
                    options: [
                        (0, "Right"),
                        (1, "Left"),
                        (2, "Auto")
                    ],
                    onChange: { bleManager.writeSetting(index: 6, value: $0) }
                )
                
                SettingRow(
                    label: "Brightness",
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
                    label: "Invert Display",
                    value: Binding(
                        get: { settings[33] == 1 },
                        set: { settings[33] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 33, value: $0 ? 1 : 0) }
                )
                
                ToggleSettingRow(
                    label: "Detailed Idle",
                    value: Binding(
                        get: { settings[13] == 1 },
                        set: { settings[13] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 13, value: $0 ? 1 : 0) }
                )
                
                ToggleSettingRow(
                    label: "Detailed Soldering",
                    value: Binding(
                        get: { settings[14] == 1 },
                        set: { settings[14] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 14, value: $0 ? 1 : 0) }
                )
            }
            
            Section("Sensors") {
                SettingRow(
                    label: "Motion Sensitivity",
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
                    label: "Hall Sensitivity",
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
            
            Section("Controls") {
                PickerSettingRow(
                    label: "Locking Mode",
                    value: Binding(
                        get: { settings[17] ?? 0 },
                        set: { settings[17] = $0 }
                    ),
                    options: [
                        (0, "Off"),
                        (1, "Boost Only"),
                        (2, "Full")
                    ],
                    onChange: { bleManager.writeSetting(index: 17, value: $0) }
                )
                
                ToggleSettingRow(
                    label: "Reverse +/- Buttons",
                    value: Binding(
                        get: { settings[25] == 1 },
                        set: { settings[25] = $0 ? 1 : 0 }
                    ),
                    onChange: { bleManager.writeSetting(index: 25, value: $0 ? 1 : 0) }
                )
                
                SettingRow(
                    label: "Short Press Step",
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
                    label: "Long Press Step",
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
                    saveInProgress = true
                    bleManager.saveSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        saveInProgress = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if saveInProgress {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Save to Device")
                        Spacer()
                    }
                }
                .disabled(saveInProgress)
            } footer: {
                Text("Changes are written immediately but must be saved to persist across restarts.")
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Loading settings...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            await loadSettings()
        }
        .onAppear {
            // Pre-populate from cache
            let settingsToLoad: [UInt16] = [0, 1, 2, 6, 7, 11, 13, 14, 17, 22, 24, 25, 26, 27, 28, 33, 34]
            for index in settingsToLoad {
                if let cached = bleManager.settingsCache.get(index) {
                    settings[Int(index)] = cached
                }
            }
        }
    }
    
    private func loadSettings() async {
        // Load commonly used settings (will use cache if available)
        let settingsToLoad: [UInt16] = [0, 1, 2, 6, 7, 11, 13, 14, 17, 22, 24, 25, 26, 27, 28, 33, 34]
        
        isLoading = true
        
        await withTaskGroup(of: (Int, UInt16?).self) { group in
            for index in settingsToLoad {
                group.addTask { @MainActor in
                    await withCheckedContinuation { (continuation: CheckedContinuation<(Int, UInt16?), Never>) in
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
            Section("Device Information") {
                InfoRow(label: "Device Name", value: bleManager.deviceName)
                InfoRow(label: "Firmware", value: bleManager.firmwareVersion.isEmpty ? "Unknown" : bleManager.firmwareVersion)
                InfoRow(label: "Build ID", value: bleManager.buildID.isEmpty ? "Unknown" : bleManager.buildID)
                InfoRow(label: "Serial Number", value: bleManager.deviceSerial.isEmpty ? "Unknown" : bleManager.deviceSerial)
            }
            
            Section("Current Status") {
                InfoRow(label: "Temperature", value: "\(bleManager.liveData.liveTemp)°C")
                InfoRow(label: "Setpoint", value: "\(bleManager.liveData.setpoint)°C")
                InfoRow(label: "Max Temperature", value: "\(bleManager.liveData.maxTemp)°C")
                InfoRow(label: "Operating Mode", value: bleManager.liveData.mode?.displayName ?? "Unknown")
            }
            
            Section("Power") {
                InfoRow(label: "Voltage", value: String(format: "%.1f V", bleManager.liveData.voltage))
                InfoRow(label: "Wattage", value: String(format: "%.1f W", bleManager.liveData.watts))
                InfoRow(label: "Power Level", value: "\(bleManager.liveData.powerPercent)%")
                InfoRow(label: "Power Source", value: bleManager.liveData.power?.displayName ?? "Unknown")
            }
            
            Section("Diagnostics") {
                InfoRow(label: "Handle Temp", value: String(format: "%.1f°C", bleManager.liveData.handleTempC))
                InfoRow(label: "Tip Resistance", value: String(format: "%.2f Ω", bleManager.liveData.resistance))
                InfoRow(label: "Raw Tip", value: "\(bleManager.liveData.rawTip) μV")
                InfoRow(label: "Hall Sensor", value: "\(bleManager.liveData.hallSensor)")
                InfoRow(label: "Uptime", value: formatUptime(bleManager.liveData.uptime))
                InfoRow(label: "Last Movement", value: formatTimeAgo(bleManager.liveData.uptime, lastMovement: bleManager.liveData.lastMovement))
            }
            
            Section {
                Button(role: .destructive) {
                    bleManager.disconnect()
                } label: {
                    HStack {
                        Spacer()
                        Text("Disconnect")
                        Spacer()
                    }
                }
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
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = UInt16($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step),
                onEditingChanged: { editing in
                    if !editing {
                        onChange(value)
                    }
                }
            )
        }
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
                value = newValue
                onChange(newValue)
            }
        ))
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
                value = newValue
                onChange(newValue)
            }
        )) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
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
    }
}
