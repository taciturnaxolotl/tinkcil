package com.tinkcil.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.tinkcil.R
import com.tinkcil.data.model.IronOSLiveData

@Composable
fun DiagnosticsContent(
    liveData: IronOSLiveData,
    deviceName: String?,
    firmwareVersion: String?,
    serialNumber: String?,
    onDisconnect: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 16.dp)
    ) {
        // Device Info
        DiagSectionHeader(stringResource(R.string.device_info_title))
        DiagRow(stringResource(R.string.info_device_name), deviceName ?: stringResource(R.string.common_unknown))
        DiagRow(stringResource(R.string.info_firmware), firmwareVersion ?: stringResource(R.string.common_unknown))
        DiagRow(stringResource(R.string.info_serial_number), serialNumber ?: stringResource(R.string.common_unknown))

        // Current Status
        DiagSectionHeader(stringResource(R.string.section_current_status))
        DiagRow(stringResource(R.string.info_temperature), "${liveData.liveTemp}°C")
        DiagRow(stringResource(R.string.info_setpoint), "${liveData.setpoint}°C")
        DiagRow(stringResource(R.string.info_max_temperature), "${liveData.maxTemp}°C")
        DiagRow(stringResource(R.string.info_operating_mode), liveData.operatingMode.label)

        // Power
        DiagSectionHeader(stringResource(R.string.section_power))
        DiagRow(stringResource(R.string.info_voltage), "%.1f V".format(liveData.dcInputVolts))
        DiagRow(stringResource(R.string.info_wattage), "%.1f W".format(liveData.estimatedWattsFloat))
        DiagRow(stringResource(R.string.info_power_level), "${liveData.powerPercent}%")
        DiagRow(stringResource(R.string.info_power_source), liveData.powerSource.label)

        // Diagnostics
        DiagSectionHeader(stringResource(R.string.section_diagnostics))
        DiagRow(stringResource(R.string.info_handle_temp), "%.1f°C".format(liveData.handleTempC))
        DiagRow(stringResource(R.string.info_tip_resistance), "%.2f Ω".format(liveData.tipResistanceOhms))
        DiagRow(stringResource(R.string.info_raw_tip), "${liveData.rawTip} μV")
        DiagRow(stringResource(R.string.info_hall_sensor), "${liveData.hallSensor}")
        DiagRow(stringResource(R.string.info_uptime), liveData.uptimeFormatted)
        DiagRow(stringResource(R.string.info_last_movement), liveData.lastMovementFormatted)

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = onDisconnect,
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.medium,
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.error
            )
        ) {
            Text(stringResource(R.string.button_disconnect))
        }
    }
}

@Composable
private fun DiagSectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 16.dp, bottom = 8.dp)
    )
    HorizontalDivider()
}

@Composable
private fun DiagRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}
