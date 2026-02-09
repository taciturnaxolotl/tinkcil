package com.tinkcil.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import com.tinkcil.data.ble.IronOSUUIDs
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>
) {
    private fun keyForIndex(index: Int) = intPreferencesKey("setting_$index")

    suspend fun getCachedSettings(): Map<Int, Int> {
        return dataStore.data.map { prefs ->
            val result = mutableMapOf<Int, Int>()
            for (index in IronOSUUIDs.SETTING_INDICES) {
                val key = keyForIndex(index)
                prefs[key]?.let { result[index] = it }
            }
            result
        }.first()
    }

    suspend fun cacheSettings(settings: Map<Int, Int>) {
        dataStore.edit { prefs ->
            for ((index, value) in settings) {
                prefs[keyForIndex(index)] = value
            }
        }
    }

    suspend fun cacheSetting(index: Int, value: Int) {
        dataStore.edit { prefs ->
            prefs[keyForIndex(index)] = value
        }
    }
}
