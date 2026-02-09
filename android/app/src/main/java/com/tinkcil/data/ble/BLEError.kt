package com.tinkcil.data.ble

sealed class BLEError(val message: String) {
    data object NotConnected : BLEError("Not connected to device")
    data object CharacteristicNotFound : BLEError("Characteristic not found")
    data class ReadFailed(val detail: String) : BLEError("Read failed: $detail")
    data class WriteFailed(val detail: String) : BLEError("Write failed: $detail")
    data object Timeout : BLEError("Operation timed out")
    data object PermissionDenied : BLEError("Bluetooth permission denied")
}
