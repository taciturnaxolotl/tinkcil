//
//  ContentView.swift
//  Tinkcil
//

import SwiftUI

struct ContentView: View {
    @State private var bleManager = BLEManager()
    @State private var targetTemp: Double = 300
    @State private var isEditingSlider = false
    @State private var lastSentTemp: Double = 0
    @State private var lastSendTime: Date = .distantPast
    @State private var isTopBarExpanded = false
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var lastConnectionState: BLEManager.ConnectionState = .disconnected
    @State private var lastMode: OperatingMode?

    private var isHeating: Bool {
        bleManager.liveData.mode?.isActive == true
    }

    var body: some View {
        ZStack {
            // Background graph
            if bleManager.temperatureHistory.count > 0 {
                TemperatureGraph(
                    history: bleManager.temperatureHistoryArray,
                    currentSetpoint: Int(targetTemp)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 120)
                .accessibilityLabel("Temperature history graph")
                .accessibilityHint("Visual representation of temperature over time")
            }

            // Main content
            if bleManager.connectionState.isConnected {
                connectedView
            } else {
                scanningView
            }
        }
        .background(Color(.systemBackground))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onChange(of: bleManager.liveData.setpoint) { _, newValue in
            if !isEditingSlider && newValue > 0 {
                targetTemp = Double(newValue)
            }
        }
        .onChange(of: bleManager.connectionState) { oldState, newState in
            handleConnectionStateChange(from: oldState, to: newState)
        }
        .onChange(of: bleManager.liveData.mode) { oldMode, newMode in
            handleModeChange(from: oldMode, to: newMode)
        }
        .onChange(of: bleManager.liveData.liveTemp) { oldTemp, newTemp in
            checkTemperatureReached(oldTemp: oldTemp, newTemp: newTemp)
        }
        .onChange(of: bleManager.lastError) { _, error in
            if error != nil {
                hapticError()
                showingError = true
            }
        }
        .alert(String(localized: "bluetooth_error_title"), isPresented: $showingError, presenting: bleManager.lastError) { _ in
            Button(String(localized: "button_ok")) {
                bleManager.lastError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 0) {
            // Top bar with stats
            topBar
                .padding(.top, 8)

            Spacer()

            // Big temperature number
            temperatureDisplay

            // Target indicator
            if isHeating {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    Text("\(bleManager.liveData.setpoint)°")
                        .font(.title3.monospacedDigit())
                }
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Target temperature \(bleManager.liveData.setpoint) degrees")
            }

            Spacer()

            // Bottom slider panel
            sliderPanel
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 0) {
            // Main top bar (always visible)
            Button {
                hapticLight()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isTopBarExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    // Device name
                    Text(bleManager.deviceName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .accessibilityLabel("Device name")
                        .accessibilityValue(bleManager.deviceName)
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 8)

                    // Stats
                    HStack(spacing: 12) {
                        statItem(value: String(format: "%.1f", bleManager.liveData.watts), unit: "W")
                            .accessibilityLabel("Power")
                            .accessibilityValue("\(String(format: "%.1f", bleManager.liveData.watts)) watts")
                        statItem(value: String(format: "%.1f", bleManager.liveData.voltage), unit: "V")
                            .accessibilityLabel("Voltage")
                            .accessibilityValue("\(String(format: "%.1f", bleManager.liveData.voltage)) volts")
                        statItem(value: "\(bleManager.liveData.powerPercent)", unit: "%")
                            .accessibilityLabel("Power level")
                            .accessibilityValue("\(bleManager.liveData.powerPercent) percent")
                    }
                    .layoutPriority(1)

                    // Mode indicator
                    if let mode = bleManager.liveData.mode {
                        Image(systemName: mode.icon)
                            .font(.caption)
                            .foregroundStyle(mode.isActive ? .orange : .secondary)
                            .accessibilityLabel("Operating mode")
                            .accessibilityValue(mode.displayName)
                    }
                    
                    // Expand chevron
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isTopBarExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTopBarExpanded ? "Collapse device details" : "Expand device details")
            .accessibilityHint("Shows detailed device information and settings")
            .accessibilityAddTraits(.isButton)
            
            // Expanded info section
            if isTopBarExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        HStack {
                            detailItem(label: String(localized: "detail_handle"), value: String(format: "%.1f°C", bleManager.liveData.handleTempC), alignment: .leading)
                            Spacer()
                            detailItem(label: String(localized: "detail_tip_resistance"), value: String(format: "%.2f Ω", bleManager.liveData.resistance), alignment: .trailing)
                        }

                        HStack {
                            detailItem(label: String(localized: "detail_mode"), value: bleManager.liveData.mode?.displayName ?? String(localized: "common_unknown"), alignment: .leading)
                            Spacer()
                            detailItem(label: String(localized: "detail_power"), value: bleManager.liveData.power?.displayName ?? String(localized: "common_unknown"), alignment: .trailing)
                        }

                        if !bleManager.firmwareVersion.isEmpty {
                            HStack {
                                detailItem(label: String(localized: "detail_firmware"), value: bleManager.firmwareVersion, alignment: .leading)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    // Settings button
                    Button {
                        hapticLight()
                        showingSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text(String(localized: "settings_button"))
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .accessibilityLabel("Settings and device information")
                    .accessibilityHint("Opens device configuration and diagnostics")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingSettings) {
            SettingsView(bleManager: bleManager)
        }
    }

    // MARK: - Temperature Display

    private var temperatureDisplay: some View {
        let currentTemp = Double(bleManager.liveData.liveTemp)
        let maxTemp = Double(bleManager.liveData.maxTemp)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(bleManager.liveData.liveTemp)")
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .contentTransition(.numericText())
            Text("°")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(colorForTemp(currentTemp, maxTemp: maxTemp))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current temperature")
        .accessibilityValue("\(bleManager.liveData.liveTemp) degrees Celsius")
        .accessibilityHint(isHeating ? "Heating to \(bleManager.liveData.setpoint) degrees" : "")
    }

    // MARK: - Slider Panel

    private var sliderPanel: some View {
        HStack(spacing: 16) {
            // Target temperature display
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int(targetTemp))")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text("°")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(colorForTemp(targetTemp, maxTemp: 450))
            .frame(width: 60)
            .accessibilityHidden(true)

            // Slider
            Slider(
                value: $targetTemp,
                in: 10...450,
                step: 5,
                onEditingChanged: { editing in
                    isEditingSlider = editing
                    if editing {
                        hapticSelection()
                        bleManager.setSlowPolling()
                    } else {
                        // Only send if value changed
                        if abs(targetTemp - lastSentTemp) >= 5 {
                            hapticLight()
                            bleManager.setTemperature(UInt32(targetTemp))
                            lastSentTemp = targetTemp
                        }
                        bleManager.setFastPolling()
                    }
                }
            )
            .tint(colorForTemp(targetTemp, maxTemp: 450))
            .accessibilityLabel("Target temperature")
            .accessibilityValue("\(Int(targetTemp)) degrees Celsius")
            .accessibilityHint("Adjust the target soldering temperature")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Helpers

    private func statItem(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(value)
                .font(.caption.monospacedDigit().bold())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
    
    private func detailItem(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func colorForTemp(_ temp: Double, maxTemp: Double) -> Color {
        let progress = min(max(temp / maxTemp, 0), 1)

        if progress < 0.33 {
            let t = progress / 0.33
            return Color(
                red: 0 + t * 0,
                green: 0.5 + t * 0.5,
                blue: 1 - t * 0
            )
        } else if progress < 0.66 {
            let t = (progress - 0.33) / 0.33
            return Color(
                red: 0 + t * 1,
                green: 1 - t * 0.35,
                blue: 1 - t * 1
            )
        } else {
            let t = (progress - 0.66) / 0.34
            return Color(
                red: 1,
                green: 0.65 - t * 0.65,
                blue: 0
            )
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                if bleManager.isScanning || bleManager.connectionState.isConnecting {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.bottom, 4)
                        .accessibilityLabel(bleManager.connectionState.isConnecting ? "Connecting to device" : "Scanning for device")

                    Text(bleManager.connectionState.isConnecting ? String(localized: "connection_connecting") : String(localized: "connection_scanning"))
                        .font(.headline)

                    Text(String(localized: "connection_looking_for_iron"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                        .accessibilityHidden(true)

                    Text(String(localized: "connection_no_device_found"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    Button(String(localized: "connection_scan_again")) {
                        hapticLight()
                        bleManager.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Scan for device")
                    .accessibilityHint("Searches for nearby soldering iron")

                    Button("Try Demo") {
                        hapticLight()
                        bleManager.startDemoMode()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Try demo mode")
                    .accessibilityHint("Experience the app with simulated soldering iron data")
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20)
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Haptic Feedback

    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    private func hapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func hapticWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func hapticError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func handleConnectionStateChange(from oldState: BLEManager.ConnectionState, to newState: BLEManager.ConnectionState) {
        switch newState {
        case .connected:
            hapticSuccess()
        case .disconnected:
            if oldState.isConnected {
                hapticWarning()
            }
        case .scanning:
            hapticLight()
        default:
            break
        }
    }

    private func handleModeChange(from oldMode: OperatingMode?, to newMode: OperatingMode?) {
        // Only trigger haptic if mode actually changed and it's a meaningful change
        guard let old = oldMode, let new = newMode, old != new else { return }

        // Haptic for entering/exiting active heating modes
        if old.isActive != new.isActive {
            hapticLight()
        }
    }

    private func checkTemperatureReached(oldTemp: UInt32, newTemp: UInt32) {
        // Check if we just reached the target temperature (within 5 degrees)
        let target = bleManager.liveData.setpoint
        guard target > 0 && isHeating else { return }

        let wasBelow = oldTemp < target - 5
        let isNear = abs(Int(newTemp) - Int(target)) <= 5

        // Trigger success haptic when we reach target for the first time
        if wasBelow && isNear {
            hapticSuccess()
        }
    }
}
