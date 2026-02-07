//
//  ContentView.swift
//  PinecilTime
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

    private var isHeating: Bool {
        bleManager.liveData.mode?.isActive ?? false
    }

    var body: some View {
        ZStack {
            // Background graph
            if !bleManager.temperatureHistory.isEmpty {
                TemperatureGraph(
                    history: bleManager.temperatureHistory,
                    currentSetpoint: Int(targetTemp)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 120)
            }

            // Main content
            if bleManager.connectionState.isConnected {
                connectedView
            } else {
                scanningView
            }
        }
        .background(Color(.systemBackground))
        .onChange(of: bleManager.liveData.setpoint) { _, newValue in
            if !isEditingSlider && newValue > 0 {
                targetTemp = Double(newValue)
            }
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

                    Spacer(minLength: 8)

                    // Stats
                    HStack(spacing: 12) {
                        statItem(value: String(format: "%.1f", bleManager.liveData.watts), unit: "W")
                        statItem(value: String(format: "%.1f", bleManager.liveData.voltage), unit: "V")
                        statItem(value: "\(bleManager.liveData.powerPercent)", unit: "%")
                    }
                    .layoutPriority(1)

                    // Mode indicator
                    if let mode = bleManager.liveData.mode {
                        Image(systemName: mode.icon)
                            .font(.caption)
                            .foregroundStyle(mode.isActive ? .orange : .secondary)
                    }
                    
                    // Expand chevron
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isTopBarExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            // Expanded info section
            if isTopBarExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        HStack {
                            detailItem(label: "Handle", value: String(format: "%.1f°C", bleManager.liveData.handleTempC))
                            Spacer()
                            detailItem(label: "Tip Resist", value: String(format: "%.2f Ω", bleManager.liveData.resistance))
                        }
                        
                        HStack {
                            detailItem(label: "Mode", value: bleManager.liveData.mode?.displayName ?? "Unknown")
                            Spacer()
                            detailItem(label: "Power", value: bleManager.liveData.power?.displayName ?? "Unknown")
                        }
                        
                        if !bleManager.firmwareVersion.isEmpty {
                            HStack {
                                detailItem(label: "Firmware", value: bleManager.firmwareVersion)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    // Settings button
                    Button {
                        showingSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings & Info")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
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

            // Slider
            Slider(
                value: $targetTemp,
                in: 10...450,
                step: 5,
                onEditingChanged: { editing in
                    isEditingSlider = editing
                    if editing {
                        bleManager.setSlowPolling()
                    } else {
                        bleManager.setTemperature(UInt32(targetTemp))
                        lastSentTemp = targetTemp
                        bleManager.setFastPolling()
                    }
                }
            )
            .tint(colorForTemp(targetTemp, maxTemp: 450))
            .onChange(of: targetTemp) { _, newValue in
                guard isEditingSlider else { return }
                let now = Date()
                if now.timeIntervalSince(lastSendTime) > 0.2 && abs(newValue - lastSentTemp) >= 5 {
                    bleManager.setTemperature(UInt32(newValue))
                    lastSentTemp = newValue
                    lastSendTime = now
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
    
    private func detailItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func colorForTemp(_ temp: Double, maxTemp: Double) -> Color {
        let progress = Swift.min(Swift.max(temp / maxTemp, 0), 1)

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

            VStack(spacing: 20) {
                if bleManager.isScanning || bleManager.connectionState.isConnecting {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.bottom, 4)

                    Text(bleManager.connectionState.isConnecting ? "Connecting..." : "Scanning...")
                        .font(.headline)

                    Text("Looking for your Pinecil")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    Text("No Device Found")
                        .font(.headline)

                    Button("Scan Again") {
                        bleManager.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20)
        }
    }
}
