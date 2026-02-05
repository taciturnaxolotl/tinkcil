//
//  Models.swift
//  PinecilTime
//

import Foundation
import SwiftUI

// MARK: - Operating Mode

enum OperatingMode: UInt32 {
    case homeScreen = 0
    case soldering = 1
    case sleeping = 3
    case settingsMenu = 4
    case solderingProfile = 6
    case thermalRunaway = 9
    case hibernating = 14

    var isActive: Bool {
        self == .soldering || self == .solderingProfile
    }

    var displayName: String {
        switch self {
        case .homeScreen: return "Idle"
        case .soldering: return "Heating"
        case .sleeping: return "Sleep"
        case .settingsMenu: return "Settings"
        case .solderingProfile: return "Profile"
        case .thermalRunaway: return "ERROR"
        case .hibernating: return "Hibernate"
        }
    }

    var icon: String {
        switch self {
        case .homeScreen: return "powerplug"
        case .soldering: return "flame.fill"
        case .sleeping: return "moon.zzz.fill"
        case .settingsMenu: return "gear"
        case .solderingProfile: return "flame"
        case .thermalRunaway: return "exclamationmark.triangle.fill"
        case .hibernating: return "snowflake"
        }
    }
}

// MARK: - Power Source

enum PowerSource: UInt32 {
    case dc = 0
    case quickCharge = 1
    case pdType1 = 2
    case pdType2 = 3

    var displayName: String {
        switch self {
        case .dc: return "DC"
        case .quickCharge: return "QC"
        case .pdType1, .pdType2: return "PD"
        }
    }
}

// MARK: - Temperature Point for Graph

struct TemperaturePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let actualTemp: UInt32
    let setpoint: UInt32
}

// MARK: - Live Data

@Observable
class IronOSLiveData {
    var liveTemp: UInt32 = 0
    var setpoint: UInt32 = 0
    var dcInput: UInt32 = 0
    var handleTemp: UInt32 = 0
    var powerLevel: UInt32 = 0
    var powerSource: UInt32 = 0
    var tipResistance: UInt32 = 0
    var uptime: UInt32 = 0
    var lastMovement: UInt32 = 0
    var maxTemp: UInt32 = 450
    var rawTip: UInt32 = 0
    var hallSensor: UInt32 = 0
    var operatingMode: UInt32 = 0
    var estimatedWatts: UInt32 = 0

    var voltage: Double { Double(dcInput) / 10.0 }
    var watts: Double { Double(estimatedWatts) / 10.0 }
    var resistance: Double { Double(tipResistance) / 100.0 }
    var handleTempC: Double { Double(handleTemp) / 10.0 }
    var powerPercent: Int { Int(Double(powerLevel) / 255.0 * 100) }

    var mode: OperatingMode? { OperatingMode(rawValue: operatingMode) }
    var power: PowerSource? { PowerSource(rawValue: powerSource) }

    var temperatureProgress: Double {
        guard maxTemp > 0 else { return 0 }
        return min(Double(liveTemp) / Double(maxTemp), 1.0)
    }

    var temperatureColor: Color {
        let progress = temperatureProgress
        if progress < 0.3 {
            return .blue
        } else if progress < 0.6 {
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        } else {
            return .red
        }
    }

    func updateFromBulkData(_ data: Data) {
        guard data.count >= 56 else { return }

        let values = data.withUnsafeBytes { buffer -> [UInt32] in
            guard let baseAddress = buffer.baseAddress else { return [] }
            return (0..<14).map { index in
                baseAddress.load(fromByteOffset: index * 4, as: UInt32.self)
            }
        }

        guard values.count == 14 else { return }

        liveTemp = values[0]
        setpoint = values[1]
        dcInput = values[2]
        handleTemp = values[3]
        powerLevel = values[4]
        powerSource = values[5]
        tipResistance = values[6]
        uptime = values[7]
        lastMovement = values[8]
        maxTemp = values[9]
        rawTip = values[10]
        hallSensor = values[11]
        operatingMode = values[12]
        estimatedWatts = values[13]
    }
}

// MARK: - Data Extensions

extension Data {
    func toUInt32() -> UInt32? {
        guard count >= 4 else { return nil }
        return withUnsafeBytes { $0.load(as: UInt32.self) }
    }

    func toUInt64() -> UInt64? {
        guard count >= 8 else { return nil }
        return withUnsafeBytes { $0.load(as: UInt64.self) }
    }

    func toString() -> String? {
        String(data: self, encoding: .utf8)
    }
}

extension UInt16 {
    var data: Data {
        withUnsafeBytes(of: self) { Data($0) }
    }
}
