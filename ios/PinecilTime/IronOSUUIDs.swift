//
//  IronOSUUIDs.swift
//  PinecilTime
//

import CoreBluetooth
import Foundation

enum IronOSUUIDs {

    // MARK: - Bulk Data Service (for discovery)
    static let bulkDataService = CBUUID(string: "9EAE1000-9D0D-48C5-AA55-33E27F9BC533")
    static let bulkLiveData = CBUUID(string: "9EAE1001-9D0D-48C5-AA55-33E27F9BC533")
    static let firmwareVersion = CBUUID(string: "9EAE1003-9D0D-48C5-AA55-33E27F9BC533")
    static let deviceSerial = CBUUID(string: "9EAE1004-9D0D-48C5-AA55-33E27F9BC533")

    // MARK: - Live Data Service
    static let liveDataService = CBUUID(string: "D85EF000-168E-4A71-AA55-33E27F9BC533")
    static let liveTemp = CBUUID(string: "D85EF001-168E-4A71-AA55-33E27F9BC533")
    static let setpointRead = CBUUID(string: "D85EF002-168E-4A71-AA55-33E27F9BC533")
    static let dcInput = CBUUID(string: "D85EF003-168E-4A71-AA55-33E27F9BC533")
    static let handleTemp = CBUUID(string: "D85EF004-168E-4A71-AA55-33E27F9BC533")
    static let powerLevel = CBUUID(string: "D85EF005-168E-4A71-AA55-33E27F9BC533")
    static let powerSource = CBUUID(string: "D85EF006-168E-4A71-AA55-33E27F9BC533")
    static let tipResistance = CBUUID(string: "D85EF007-168E-4A71-AA55-33E27F9BC533")
    static let uptime = CBUUID(string: "D85EF008-168E-4A71-AA55-33E27F9BC533")
    static let lastMovement = CBUUID(string: "D85EF009-168E-4A71-AA55-33E27F9BC533")
    static let maxTemp = CBUUID(string: "D85EF00A-168E-4A71-AA55-33E27F9BC533")
    static let rawTip = CBUUID(string: "D85EF00B-168E-4A71-AA55-33E27F9BC533")
    static let hallSensor = CBUUID(string: "D85EF00C-168E-4A71-AA55-33E27F9BC533")
    static let operatingMode = CBUUID(string: "D85EF00D-168E-4A71-AA55-33E27F9BC533")
    static let estimatedWatts = CBUUID(string: "D85EF00E-168E-4A71-AA55-33E27F9BC533")

    // MARK: - Settings Service
    static let settingsService = CBUUID(string: "F6D80000-5A10-4EBA-AA55-33E27F9BC533")
    // Setting 0 = Setpoint temperature (writable)
    static let setpointSetting = CBUUID(string: "F6D70000-5A10-4EBA-AA55-33E27F9BC533")
    static let saveSettings = CBUUID(string: "F6D7FFFF-5A10-4EBA-AA55-33E27F9BC533")
    static let resetSettings = CBUUID(string: "F6D7FFFE-5A10-4EBA-AA55-33E27F9BC533")
}
