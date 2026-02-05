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

    private var isHeating: Bool {
        bleManager.liveData.mode?.isActive ?? false
    }

    var body: some View {
        ZStack {
            // Background graph
            if !bleManager.temperatureHistory.isEmpty {
                TemperatureGraph(
                    history: bleManager.temperatureHistory,
                    maxTemp: bleManager.liveData.maxTemp
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
        HStack(spacing: 16) {
            // Device name
            Text(bleManager.deviceName)
                .font(.subheadline.bold())

            Spacer()

            // Stats
            HStack(spacing: 12) {
                statItem(value: String(format: "%.1f", bleManager.liveData.watts), unit: "W")
                statItem(value: String(format: "%.1f", bleManager.liveData.voltage), unit: "V")
                statItem(value: "\(bleManager.liveData.powerPercent)", unit: "%")
            }

            // Mode indicator
            if let mode = bleManager.liveData.mode {
                Image(systemName: mode.icon)
                    .foregroundStyle(mode.isActive ? .orange : .secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
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
        VStack(spacing: 12) {
            HStack {
                Text("Target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(targetTemp))°C")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(colorForTemp(targetTemp, maxTemp: 450))
            }

            Slider(
                value: $targetTemp,
                in: 10...450,
                step: 5,
                onEditingChanged: { editing in
                    isEditingSlider = editing
                    if !editing {
                        bleManager.setTemperature(UInt32(targetTemp))
                        lastSentTemp = targetTemp
                    }
                }
            )
            .tint(colorForTemp(targetTemp, maxTemp: 450))
            .onChange(of: targetTemp) { _, newValue in
                guard isEditingSlider else { return }
                let now = Date()
                if now.timeIntervalSince(lastSendTime) > 0.15 && abs(newValue - lastSentTemp) >= 5 {
                    bleManager.setTemperature(UInt32(newValue))
                    lastSentTemp = newValue
                    lastSendTime = now
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
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
                if bleManager.isScanning || bleManager.connectionState == .connecting {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.bottom, 4)

                    Text(bleManager.connectionState == .connecting ? "Connecting..." : "Scanning...")
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
