package com.tinkcil.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.tinkcil.R
import com.tinkcil.data.model.IronOSLiveData

@Composable
fun DeviceDetailStats(
    liveData: IronOSLiveData,
    firmwareVersion: String?,
    onSettingsClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                DetailRow(stringResource(R.string.detail_handle), "%.1f°C".format(liveData.handleTempC))
                DetailRow(stringResource(R.string.detail_tip_resistance), "%.2f Ω".format(liveData.tipResistanceOhms))
                DetailRow(stringResource(R.string.detail_mode), liveData.operatingMode.label)
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                DetailRow(stringResource(R.string.detail_power), liveData.powerSource.label)
                DetailRow(
                    stringResource(R.string.detail_firmware),
                    firmwareVersion ?: stringResource(R.string.common_unknown)
                )
            }
        }

        Button(
            onClick = onSettingsClick,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            shape = MaterialTheme.shapes.medium
        ) {
            Text(stringResource(R.string.settings_button))
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}
