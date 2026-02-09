package com.tinkcil.data.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Nightlight
import androidx.compose.material.icons.filled.Power
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Warning
import androidx.compose.ui.graphics.vector.ImageVector

enum class OperatingMode(val raw: Int, val label: String, val icon: ImageVector, val isActive: Boolean = false) {
    IDLE(0, "Idle", Icons.Filled.Power),
    HEATING(1, "Heating", Icons.Filled.LocalFireDepartment, isActive = true),
    SLEEP(3, "Sleep", Icons.Filled.Nightlight),
    SETTINGS_MENU(4, "Settings", Icons.Filled.Settings),
    PROFILE(6, "Profile", Icons.Filled.LocalFireDepartment, isActive = true),
    ERROR(9, "ERROR", Icons.Filled.Warning),
    HIBERNATING(14, "Hibernate", Icons.Filled.AcUnit);

    companion object {
        fun fromRaw(value: Int): OperatingMode =
            entries.find { it.raw == value } ?: IDLE
    }
}
