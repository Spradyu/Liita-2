package com.liita.liita

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import java.util.concurrent.ConcurrentHashMap

/**
 * Tracks connected GATT clients for relaying packets.
 */
class BlePeerRegistry {
    // Map of MAC address to BluetoothGatt
    private val connectedGatts = ConcurrentHashMap<String, BluetoothGatt>()
    
    // Track discovered peers (Profile JSON) for the EventChannel
    private val discoveredPeers = ConcurrentHashMap<String, String>()

    // Track all known BluetoothDevice objects for ephemeral connections
    private val knownDevices = ConcurrentHashMap<String, BluetoothDevice>()

    fun addConnection(gatt: BluetoothGatt) {
        connectedGatts[gatt.device.address] = gatt
    }

    fun removeConnection(address: String) {
        connectedGatts.remove(address)
    }

    fun getAllConnections(): List<BluetoothGatt> {
        return connectedGatts.values.toList()
    }

    fun addKnownDevice(device: BluetoothDevice) {
        knownDevices[device.address] = device
    }

    fun getAllKnownDevices(): List<BluetoothDevice> {
        return knownDevices.values.toList()
    }
    
    fun updatePeerProfile(deviceId: String, profileJson: String): Boolean {
        val existing = discoveredPeers[deviceId]
        if (existing != profileJson) {
            discoveredPeers[deviceId] = profileJson
            return true
        }
        return false
    }

    fun clear() {
        for (gatt in connectedGatts.values) {
            try {
                gatt.disconnect()
                gatt.close()
            } catch (e: Exception) {}
        }
        connectedGatts.clear()
        discoveredPeers.clear()
        knownDevices.clear()
    }
}
