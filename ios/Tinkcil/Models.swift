//
//  Models.swift
//  Tinkcil
//

import CoreBluetooth
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

// MARK: - Circular Buffer

@Observable
class CircularBuffer<T> {
    private var buffer: [T]
    private var writeIndex = 0
    private(set) var isFull = false
    private var cachedElements: [T]?
    private var cacheInvalidated = false
    let capacity: Int

    var elements: [T] {
        if cacheInvalidated {
            cachedElements = computeElements()
            cacheInvalidated = false
        }
        return cachedElements ?? computeElements()
    }

    var count: Int {
        isFull ? capacity : writeIndex
    }

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = []
        self.buffer.reserveCapacity(capacity)
    }

    func append(_ element: T) {
        if buffer.count < capacity {
            buffer.append(element)
            writeIndex = buffer.count
            if writeIndex == capacity {
                isFull = true
                writeIndex = 0
            }
        } else {
            buffer[writeIndex] = element
            writeIndex = (writeIndex + 1) % capacity
            isFull = true
        }
        cacheInvalidated = true
    }

    func clear() {
        buffer.removeAll(keepingCapacity: true)
        writeIndex = 0
        isFull = false
        cachedElements = nil
        cacheInvalidated = false
    }

    private func computeElements() -> [T] {
        if isFull {
            return Array(buffer[writeIndex...]) + Array(buffer[..<writeIndex])
        } else {
            return Array(buffer[..<writeIndex])
        }
    }
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
        // Validate data size (14 UInt32 values = 56 bytes)
        guard data.count == 56 else { return }

        let values = data.withUnsafeBytes { buffer -> [UInt32] in
            guard let baseAddress = buffer.baseAddress else { return [] }
            return (0..<14).map { index in
                baseAddress.load(fromByteOffset: index * 4, as: UInt32.self)
            }
        }

        guard values.count == 14 else { return }

        // Basic validation of values
        let temp = values[0]
        let maxTempValue = values[9]

        // Sanity check temperatures (0-600°C range)
        guard temp <= 600, maxTempValue <= 600 else { return }

        liveTemp = temp
        setpoint = values[1]
        dcInput = values[2]
        handleTemp = values[3]
        powerLevel = min(values[4], 255) // Power level should be 0-255
        powerSource = values[5]
        tipResistance = values[6]
        uptime = values[7]
        lastMovement = values[8]
        maxTemp = maxTempValue
        rawTip = values[10]
        hallSensor = values[11]
        operatingMode = values[12]
        estimatedWatts = values[13]
    }
}

// MARK: - Data Extensions

extension Data {
    func toUInt32() -> UInt32? {
        guard count >= MemoryLayout<UInt32>.size else { return nil }
        return withUnsafeBytes { $0.load(as: UInt32.self) }
    }

    func toUInt64() -> UInt64? {
        guard count >= MemoryLayout<UInt64>.size else { return nil }
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

// MARK: - Settings Cache

@Observable
class SettingsCache {
    private(set) var cache: [UInt16: UInt16] = [:]
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "tinkcilSettingsCache"
    
    init() {
        loadFromDisk()
    }
    
    func set(_ value: UInt16, for index: UInt16) {
        cache[index] = value
        saveToDisk()
    }
    
    func get(_ index: UInt16) -> UInt16? {
        cache[index]
    }
    
    func clear() {
        cache.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    private func saveToDisk() {
        let data = cache.map { ["index": $0.key, "value": $0.value] }
        userDefaults.set(data, forKey: cacheKey)
    }
    
    private func loadFromDisk() {
        guard let data = userDefaults.array(forKey: cacheKey) as? [[String: UInt16]] else { return }
        cache = Dictionary(uniqueKeysWithValues: data.compactMap { dict in
            guard let index = dict["index"], let value = dict["value"] else { return nil }
            return (index, value)
        })
    }
}

// MARK: - BLE Error

enum BLEError: LocalizedError, Equatable {
    case notConnected
    case characteristicNotFound(CBUUID)
    case readFailed(String)
    case writeFailed(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Device not connected"
        case .characteristicNotFound(let uuid):
            return "Characteristic not found: \(uuid.uuidString)"
        case .readFailed(let reason):
            return "Read failed: \(reason)"
        case .writeFailed(let reason):
            return "Write failed: \(reason)"
        case .timeout:
            return "Operation timed out"
        }
    }
}
