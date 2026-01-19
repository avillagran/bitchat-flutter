# Research Report: bluetooth_low_energy GATT Service Discovery Issues on macOS

Generated: 2026-01-16

## Executive Summary

The `bluetooth_low_energy` Flutter package has limited documented issues specific to macOS GATT service discovery timeouts. However, the underlying CoreBluetooth framework has well-known limitations: it provides no built-in timeout for service discovery operations, and cross-platform BLE communication (macOS to Android peripherals) can fail silently when services aren't discovered. The 15-second timeout is likely implemented by the Flutter package itself, not CoreBluetooth.

## Research Question

Why does `discoverGATT()` timeout after 15 seconds on macOS when connecting to an Android GATT server, even though the connection succeeds?

## Key Findings

### Finding 1: CoreBluetooth Has No Native Timeout for Service Discovery

CoreBluetooth's `discoverServices()` method has no built-in timeout mechanism. If the delegate callback `didDiscoverServices` is never called, the operation hangs indefinitely unless a manual timeout is implemented.

> "Core Bluetooth will never timeout when scanning, so you'll probably want to create some timeout of your own (10s is a good starting point)"

- Source: [Splinter Software - iOS Swift Bluetooth LE Guide](http://www.splinter.com.au/2019/05/18/ios-swift-bluetooth-le/)

### Finding 2: bluetooth_low_energy Package Known Fixes

The `bluetooth_low_energy` changelog shows relevant fixes but no specific macOS service discovery timeout issues:

| Version | Fix |
|---------|-----|
| 5.0.2 | iOS: Fix discoverGATT failed caused by CoW (Copy-on-Write) |
| 5.0.1 | iOS: Fix completion called duplicately caused by CoW |
| 6.2.0 | iOS/macOS: Fix race condition when isReady is delivered early |
| 2.0.1 | iOS/macOS: Fix GATTs cleared after peripheral disconnected |

- Source: [bluetooth_low_energy changelog](https://pub.dev/packages/bluetooth_low_energy/changelog)

### Finding 3: No Specific macOS-Android GATT Discovery Issues in Repository

After searching the [yanshouwang/bluetooth_low_energy GitHub issues](https://github.com/yanshouwang/bluetooth_low_energy/issues), no issues were found specifically about:
- macOS/Darwin `discoverGATT()` timeout
- Android peripheral service discovery failures from macOS
- 15-second timeout issues

The open issues are mostly about advertising UUIDs, connection persistence, and service change listeners.

### Finding 4: CoreBluetooth Service Discovery Can Silently Fail

Multiple sources document that `didDiscoverServices` may never be called:

1. **Background mode issues**: If the peripheral app is backgrounded, services may be stripped from advertisements
2. **Delegate misconfiguration**: API MISUSE error if delegate is nil or doesn't implement the callback
3. **Bonding requirements**: Some services aren't visible until bonding/pairing completes
4. **Custom vs Standard UUIDs**: CoreBluetooth may not discover custom GATT services while standard BLE services are found

- Source: [Apple Developer Forums - CoreBluetooth not discovering services](https://developer.apple.com/forums/thread/86694)

### Finding 5: Cross-Platform Service Discovery Challenges

When macOS (Central) connects to Android (Peripheral):

1. **No explicit bonding API in CoreBluetooth**: Unlike Android, iOS/macOS cannot programmatically initiate bonding. The workaround is to read an encrypted characteristic to force bonding.

2. **Service must be marked as primary**: If the Android GATT server doesn't mark services as primary, they may not be discoverable.

3. **UUID caching**: CoreBluetooth caches service UUIDs. If the peripheral's services change, you may need to "Forget this device" in Bluetooth settings.

- Source: [Punch Through - Core Bluetooth Guide](https://punchthrough.com/core-bluetooth-guide/)

### Finding 6: macOS-Specific Sandbox Requirements

For macOS apps using CoreBluetooth, the sandbox must be properly configured:

1. Enable Bluetooth in sandbox capabilities
2. Add `NSBluetoothAlwaysUsageDescription` to Info.plist
3. For sandboxed apps, peripheral mode has additional restrictions

- Source: [bluetooth_low_energy_darwin package](https://pub.dev/packages/bluetooth_low_energy_darwin)

## Codebase Analysis

This research was focused on external documentation. If the project has existing BLE code, consider checking:
- Whether `setUp()` is called before `discoverGATT()`
- Whether the macOS app has proper sandbox/entitlements configuration
- Whether the Android peripheral marks services as primary

## Potential Root Causes for the 15-Second Timeout

1. **Android GATT server not advertising services correctly** - Services may not be marked as primary or may not be included in advertisement data

2. **Bonding/pairing required but not triggered** - The peripheral may require bonding before exposing services, but CoreBluetooth won't automatically initiate this

3. **Race condition in the Flutter package** - Version 6.2.0 fixed a race condition "when isReady is delivered early" - ensure you're on latest version

4. **Copy-on-Write (CoW) issue** - Version 5.0.2 fixed discoverGATT failures caused by Swift CoW behavior on iOS (may affect macOS too)

5. **Connection not fully established** - `didConnect` is called before bonding completes; service discovery may fail if called too early

## Workarounds to Try

### 1. Add delay before service discovery
```dart
await centralManager.connect(peripheral);
await Future.delayed(Duration(seconds: 1)); // Allow bonding to complete
final gatt = await centralManager.discoverGATT(peripheral);
```

### 2. Verify Android GATT server configuration
Ensure services are:
- Marked as primary (`BluetoothGattService.SERVICE_TYPE_PRIMARY`)
- Using valid 128-bit UUIDs
- Started before advertising begins

### 3. Update to latest package version
The package has had fixes for discoverGATT issues through version 6.2.0.

### 4. Test with native BLE scanner
Use nRF Connect on the Mac to verify the Android peripheral is properly exposing services. If nRF Connect can see the services, the issue is in the Flutter layer.

### 5. Check macOS sandbox configuration
For macOS apps, ensure:
```xml
<!-- Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>App needs Bluetooth to connect to devices</string>

<!-- Entitlements -->
<key>com.apple.security.device.bluetooth</key>
<true/>
```

### 6. Try specifying service UUIDs
Instead of discovering all services, specify the expected UUID:
```dart
final gatt = await centralManager.discoverGATT(
  peripheral,
  serviceUUIDs: [myServiceUUID], // May be faster
);
```

## Sources

- [bluetooth_low_energy package](https://pub.dev/packages/bluetooth_low_energy)
- [bluetooth_low_energy_darwin package](https://pub.dev/packages/bluetooth_low_energy_darwin)
- [bluetooth_low_energy changelog](https://pub.dev/packages/bluetooth_low_energy/changelog)
- [GitHub: yanshouwang/bluetooth_low_energy](https://github.com/yanshouwang/bluetooth_low_energy)
- [Punch Through - Core Bluetooth Guide](https://punchthrough.com/core-bluetooth-guide/)
- [Apple Developer Forums - CoreBluetooth not discovering services](https://developer.apple.com/forums/thread/86694)
- [Splinter Software - iOS Swift Bluetooth LE Guide](http://www.splinter.com.au/2019/05/18/ios-swift-bluetooth-le/)
- [Apple Documentation - discoverServices](https://developer.apple.com/documentation/corebluetooth/cbperipheral/1518706-discoverservices)
- [Apple Documentation - didDiscoverServices](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518744-peripheral)

## Open Questions

1. **What timeout does bluetooth_low_energy_darwin use?** - The 15-second timeout may be hardcoded in the package. Would need to inspect the source code.

2. **Is bonding required by the Android GATT server?** - If the peripheral requires bonding, CoreBluetooth won't expose services until bonding completes, which may never happen automatically.

3. **Does nRF Connect see the services?** - This would isolate whether the issue is the Android peripheral or the Flutter/macOS stack.

4. **What version of bluetooth_low_energy is in use?** - Versions before 5.0.2 had discoverGATT issues on iOS/macOS due to CoW bugs.

## Recommendations

1. **First**: Verify the Android peripheral exposes services correctly using nRF Connect for macOS
2. **Second**: Ensure using `bluetooth_low_energy` version 6.2.0 or later
3. **Third**: Add a delay after connection before calling `discoverGATT()`
4. **Fourth**: If bonding is required, attempt to read an encrypted characteristic to trigger the pairing flow
5. **Fifth**: Consider filing an issue on the bluetooth_low_energy repository with detailed logs if the above don't resolve the issue
