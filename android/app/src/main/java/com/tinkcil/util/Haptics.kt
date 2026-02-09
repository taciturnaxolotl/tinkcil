package com.tinkcil.util

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object Haptics {

    private fun vibrator(context: Context): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    fun light(context: Context) {
        vibrate(context, 10, VibrationEffect.EFFECT_TICK)
    }

    fun selection(context: Context) {
        vibrate(context, 15, VibrationEffect.EFFECT_CLICK)
    }

    fun success(context: Context) {
        vibrate(context, 30, VibrationEffect.EFFECT_HEAVY_CLICK)
    }

    fun warning(context: Context) {
        vibrate(context, 50, VibrationEffect.EFFECT_DOUBLE_CLICK)
    }

    fun error(context: Context) {
        vibrate(context, 100, VibrationEffect.EFFECT_DOUBLE_CLICK)
    }

    private fun vibrate(context: Context, durationMs: Long, effectId: Int) {
        val v = vibrator(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            v.vibrate(VibrationEffect.createPredefined(effectId))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(durationMs)
        }
    }
}
