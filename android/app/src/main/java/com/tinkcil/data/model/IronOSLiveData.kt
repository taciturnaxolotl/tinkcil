package com.tinkcil.data.model

data class IronOSLiveData(
    val liveTemp: Int = 0,
    val setpoint: Int = 0,
    val dcInput: Int = 0,
    val handleTemp: Int = 0,
    val powerLevel: Int = 0,
    val powerSource: PowerSource = PowerSource.DC,
    val tipResistance: Int = 0,
    val uptime: Int = 0,
    val lastMovement: Int = 0,
    val maxTemp: Int = 0,
    val rawTip: Int = 0,
    val hallSensor: Int = 0,
    val operatingMode: OperatingMode = OperatingMode.IDLE,
    val estimatedWatts: Int = 0
) {
    val dcInputVolts: Float get() = dcInput / 10f
    val handleTempC: Float get() = handleTemp / 10f
    val powerPercent: Int get() = if (powerLevel > 0) (powerLevel * 100 / 255).coerceIn(0, 100) else 0
    val tipResistanceOhms: Float get() = tipResistance / 100f
    val uptimeSeconds: Int get() = uptime / 10
    val lastMovementSeconds: Int get() = lastMovement / 10
    val estimatedWattsFloat: Float get() = estimatedWatts / 10f

    val uptimeFormatted: String get() {
        val totalSeconds = uptimeSeconds
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return "%02d:%02d:%02d".format(hours, minutes, seconds)
    }

    val lastMovementFormatted: String get() {
        val seconds = lastMovementSeconds
        return when {
            seconds < 2 -> "just now"
            seconds < 60 -> "${seconds}s ago"
            seconds < 3600 -> "${seconds / 60}m ago"
            else -> "${seconds / 3600}h ${(seconds % 3600) / 60}m ago"
        }
    }
}
