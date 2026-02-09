package com.tinkcil.data.ble

import java.util.UUID

object IronOSUUIDs {
    // Services
    val BULK_DATA_SERVICE: UUID = UUID.fromString("9eae1000-9d0d-48c5-aa55-33e27f9bc533")
    val LIVE_DATA_SERVICE: UUID = UUID.fromString("d85ef000-168e-4a71-aa55-33e27f9bc533")
    val SETTINGS_SERVICE: UUID = UUID.fromString("f6d80000-5a10-4eba-aa55-33e27f9bc533")

    // Bulk data characteristics
    val BULK_LIVE_DATA: UUID = UUID.fromString("9eae1001-9d0d-48c5-aa55-33e27f9bc533")
    val BUILD_ID: UUID = UUID.fromString("9eae1003-9d0d-48c5-aa55-33e27f9bc533")
    val DEVICE_SERIAL: UUID = UUID.fromString("9eae1004-9d0d-48c5-aa55-33e27f9bc533")

    // Settings control
    val SAVE_SETTINGS: UUID = UUID.fromString("f6d7ffff-5a10-4eba-aa55-33e27f9bc533")
    val RESET_SETTINGS: UUID = UUID.fromString("f6d7fffe-5a10-4eba-aa55-33e27f9bc533")

    // Setting characteristic by index
    fun settingCharacteristic(index: Int): UUID =
        UUID.fromString("f6d7%04x-5a10-4eba-aa55-33e27f9bc533".format(index))

    // All setting indices used by the app
    val SETTING_INDICES = intArrayOf(0, 1, 2, 6, 7, 11, 13, 14, 17, 22, 24, 25, 26, 27, 28, 33, 34)
}
