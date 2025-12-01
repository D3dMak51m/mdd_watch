package com.mdd.watch.ble

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** MddBlePlugin */
class MddBlePlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel : EventChannel
    private lateinit var context: Context

    // Делаем менеджер статическим (синглтоном), чтобы он был общим
    // между UI-движком и Background-движком.
    // Иначе при запуске фона создастся новый сервер, который будет конфликтовать с первым.
    companion object {
        private var bleServerManager: BleServerManager? = null
        private var eventSink: EventChannel.EventSink? = null
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.mdd.watch/ble_server")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.mdd.watch/ble_events")
        eventChannel.setStreamHandler(this)

        // Инициализируем менеджер один раз
        if (bleServerManager == null) {
            bleServerManager = BleServerManager(context) { type, data ->
                // Отправка событий в Dart (в UI поток)
                Handler(Looper.getMainLooper()).post {
                    val eventMap = mapOf("type" to type, "data" to data)
                    // Внимание: eventSink будет указывать на тот изолят, который последним подписался.
                    // В нашем случае это будет Background Service.
                    eventSink?.success(eventMap)
                }
            }
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startServer" -> {
                val name = call.argument<String>("name") ?: "MDD Watch"
                bleServerManager?.startServer(name) // Используем новый метод
                result.success(null)
            }
            "stopServer" -> {
                bleServerManager?.stopServer()
                result.success(null)
            }
            "updateSos" -> {
                val payload = call.argument<String>("payload")
                if (payload != null) {
                    bleServerManager?.updateSosValue(payload)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Payload is null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        // Не зануляем sink сразу, так как может переподключиться другой изолят
        // Но для чистоты можно, если логика позволяет.
        // eventSink = null
    }
}