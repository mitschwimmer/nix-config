import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import QtQuick
import "SidebarLogic.js" as Logic

Scope {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property real batteryLevel: hasBattery ? Logic.batteryLevel(battery.percentage) : 0
    readonly property string batteryValue: hasBattery ? Math.round(batteryLevel * 100) + "%" : "AC power"
    readonly property string batteryDetail: {
        if (!hasBattery) return "No system battery"
        const state = UPowerDeviceState.toString(battery.state)
        const estimate = Logic.duration(battery.state === UPowerDeviceState.Charging
            ? battery.timeToFull : battery.timeToEmpty)
        return state + (estimate ? " · " + estimate : "")
    }

    readonly property var wifiDevices: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
    readonly property var wifiDevice: wifiDevices.find(device => device.connected) || wifiDevices[0] || null
    readonly property var wifiNetwork: wifiDevice
        ? wifiDevice.networks.values.find(network => network.connected) || null : null
    readonly property string wifiValue: {
        if (!wifiDevice) return "Unavailable"
        if (!Networking.wifiHardwareEnabled) return "Blocked"
        if (!Networking.wifiEnabled) return "Off"
        return wifiNetwork ? wifiNetwork.name : ConnectionState.toString(wifiDevice.state)
    }
    readonly property string wifiDetail: wifiNetwork
        ? "Connected · " + Math.round(wifiNetwork.signalStrength * 100) + "%"
        : wifiDevice ? ConnectionState.toString(wifiDevice.state) : "No Wi-Fi adapter"

    readonly property bool bluetoothEnabled: Bluetooth.adapters.values.some(adapter => adapter.enabled)
    readonly property var connectedDevices: Bluetooth.devices.values.filter(device => device.connected)
    readonly property string bluetoothValue: connectedDevices.length
        ? connectedDevices.map(device => device.name).join(", ")
        : bluetoothEnabled ? "On" : Bluetooth.adapters.values.length ? "Off" : "Unavailable"
    readonly property string bluetoothDetail: connectedDevices.length
        ? "Connected" : bluetoothEnabled ? "No connected devices" : "Bluetooth disabled"
}
