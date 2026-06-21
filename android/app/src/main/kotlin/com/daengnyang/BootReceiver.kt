package com.daengnyang

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class BootReceiver : BroadcastReceiver() {
    companion object {
        // GC 방지용 참조 — Dart 코드가 끝나면 프로세스가 종료되면서 자동 해제됨
        @Volatile
        private var activeEngine: FlutterEngine? = null
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.MY_PACKAGE_REPLACED" &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) return

        val appContext = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(appContext)
        loader.ensureInitializationComplete(appContext, null)

        val engine = FlutterEngine(appContext)
        activeEngine = engine
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "rescheduleNotificationsOnBoot"
            )
        )
    }
}
