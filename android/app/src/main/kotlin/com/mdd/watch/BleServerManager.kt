package com.mdd.watch

import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.*

class BleServerManager(private val context: Context, private val onEvent: (String, Any?) -> Unit) {

    private var bluetoothManager: BluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private var bluetoothAdapter: BluetoothAdapter = bluetoothManager.adapter
    private var gattServer: BluetoothGattServer? = null

    // UUIDs (Должны совпадать с константами в Dart)
    private val SERVICE_UUID = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
    private val SOS_CHAR_UUID = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
    private val ACK_CHAR_UUID = UUID.fromString("00002a38-0000-1000-8000-00805f9b34fb")
    private val CONFIG_CHAR_UUID = UUID.fromString("00002a39-0000-1000-8000-00805f9b34fb")

    // Список подключенных устройств (для рассылки уведомлений)
    private val registeredDevices = mutableSetOf<BluetoothDevice>()

    fun startServer() {
        if (!bluetoothAdapter.isEnabled) {
            Log.e("BleServer", "Bluetooth is disabled")
            return
        }

        // 1. Открываем GATT сервер
        gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
        if (gattServer == null) {
            Log.e("BleServer", "Unable to create GATT server")
            return
        }

        // 2. Создаем сервис
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // 3. Характеристика SOS (Notify/Read)
        val sosChar = BluetoothGattCharacteristic(
            SOS_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        // Дескриптор для уведомлений (обязателен для Android/iOS совместимости)
        val clientConfigDesc = BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        sosChar.addDescriptor(clientConfigDesc)
        service.addCharacteristic(sosChar)

        // 4. Характеристика ACK (Write)
        val ackChar = BluetoothGattCharacteristic(
            ACK_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(ackChar)

        // 5. Характеристика Config (Write)
        val configChar = BluetoothGattCharacteristic(
            CONFIG_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(configChar)

        // 6. Добавляем сервис в сервер
        gattServer?.addService(service)

        // 7. Запускаем рекламу (Advertising)
        startAdvertising()
    }

    private fun startAdvertising() {
        val advertiser = bluetoothAdapter.bluetoothLeAdvertiser
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true) // Важно для обнаружения по имени
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        advertiser.startAdvertising(settings, data, advertiseCallback)
        Log.d("BleServer", "Advertising started")
    }

    fun stopServer() {
        bluetoothAdapter.bluetoothLeAdvertiser.stopAdvertising(advertiseCallback)
        gattServer?.close()
        Log.d("BleServer", "Server stopped")
    }

    fun updateSosValue(payload: String) {
        val characteristic = gattServer?.getService(SERVICE_UUID)?.getCharacteristic(SOS_CHAR_UUID)
        if (characteristic != null) {
            characteristic.value = payload.toByteArray(Charsets.UTF_8)

            // Уведомляем всех подписанных клиентов
            for (device in registeredDevices) {
                gattServer?.notifyCharacteristicChanged(device, characteristic, false)
            }
            Log.d("BleServer", "SOS Updated & Notified: $payload")
        }
    }

    // --- CALLBACKS ---

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            Log.i("BleServer", "LE Advertise success.")
        }
        override fun onStartFailure(errorCode: Int) {
            Log.e("BleServer", "LE Advertise failed: $errorCode")
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i("BleServer", "Device connected: ${device.address}")
                registeredDevices.add(device)
                onEvent("connectionState", mapOf("state" to "connected", "deviceId" to device.address))
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.i("BleServer", "Device disconnected: ${device.address}")
                registeredDevices.remove(device)
                onEvent("connectionState", mapOf("state" to "disconnected", "deviceId" to device.address))
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)

            // Обязательно отправляем ответ, иначе клиент (телефон) отвалится по таймауту
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }

            // Обработка полученных данных
            if (characteristic.uuid == ACK_CHAR_UUID) {
                // Пришел ACK (0x01 - успех, 0x00 - ошибка)
                val success = value.isNotEmpty() && value[0].toInt() == 1
                onEvent("ackReceived", mapOf("success" to success))
            } else if (characteristic.uuid == CONFIG_CHAR_UUID) {
                // Пришел конфиг [sensitivity, timeout]
                if (value.size >= 2) {
                    val sensitivity = value[0].toInt()
                    val timeout = value[1].toInt()
                    onEvent("configReceived", mapOf("sensitivity" to sensitivity, "timeout" to timeout))
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            // Обработка подписки на уведомления (CCCD)
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
            if (Arrays.equals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE, value)) {
                registeredDevices.add(device)
                Log.d("BleServer", "Notifications enabled for ${device.address}")
            }
        }
    }
}