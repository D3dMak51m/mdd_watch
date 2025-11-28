package com.mdd.watch

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.mdd.watch/ble_server"
    private val EVENT_CHANNEL = "com.mdd.watch/ble_events"

    private var bleServerManager: BleServerManager? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Инициализация менеджера
        bleServerManager = BleServerManager(context) { type, data ->
            // Отправка событий во Flutter (нужно делать в UI потоке)
            runOnUiThread {
                val eventMap = mapOf("type" to type, "data" to data)
                eventSink?.success(eventMap)
            }
        }

        // Настройка MethodChannel (Вызовы из Flutter)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer" -> {
                    bleServerManager?.startServer()
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

        // Настройка EventChannel (События во Flutter)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }
}