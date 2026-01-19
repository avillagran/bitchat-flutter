# Debug Report: macOS BLE Not Discovering Devices
Generated: 2026-01-16

## Symptom
macOS BLE is not discovering any devices. The app builds and runs after the TCC fix (lazy CBCentralManager initialization), but no BLE devices are being discovered.

## Investigation Steps

1. **Checked macOS entitlements** - Both DebugProfile.entitlements and Release.entitlements have `com.apple.security.device.bluetooth` set to true. Entitlements are correct.

2. **Checked Info.plist** - Contains `NSBluetoothAlwaysUsageDescription`. Usage description is present.

3. **Reviewed BleManager initialization flow** - BleManager.initialize() is called from `bluetooth_mesh_service.dart:125` and `onboarding_coordinator.dart:85`. Initialization occurs in both flows.

4. **Analyzed the local bluetooth_low_energy_bitchat package** - Found critical issues in the lazy initialization implementation.

5. **Traced Swift CBCentralManager creation** - Found the delegate is not set at creation time.

## Evidence

### Finding 1: CBCentralManager created without delegate
- **Location:** `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/darwin/Classes/MyCentralManager.swift:73-78`
- **Observation:** The `getCentralManager()` method creates `CBCentralManager()` without passing a delegate:
  ```swift
  private func getCentralManager() -> CBCentralManager {
      if mCentralManager == nil {
          mCentralManager = CBCentralManager()  // NO DELEGATE!
      }
      return mCentralManager!
  }
  ```
- **Relevance:** When CBCentralManager is created without a delegate, the initial state change callback (`centralManagerDidUpdateState`) is never received. This means the app never learns when Bluetooth is ready (poweredOn state).

### Finding 2: Delegate set too late in initialize()
- **Location:** `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/darwin/Classes/MyCentralManager.swift:80-113`
- **Observation:** The delegate is only set at line 112 during `initialize()`:
  ```swift
  func initialize() throws {
      let centralManager = getCentralManager()  // Creates manager WITHOUT delegate
      // ... cleanup code ...
      centralManager.delegate = mCentralManagerDelegate  // Delegate set AFTER creation
  }
  ```
- **Relevance:** By the time the delegate is set, the `centralManagerDidUpdateState` callback has already fired (immediately after CBCentralManager creation on macOS). The delegate misses this callback, so the Flutter side never receives the state update.

### Finding 3: Same issue in CBPeripheralManager
- **Location:** `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/darwin/Classes/MyPeripheralManager.swift:62-67`
- **Observation:** Same pattern - `CBPeripheralManager()` created without delegate:
  ```swift
  private func getPeripheralManager() -> CBPeripheralManager {
      if mPeripheralManager == nil {
          mPeripheralManager = CBPeripheralManager()  // NO DELEGATE!
      }
      return mPeripheralManager!
  }
  ```
- **Relevance:** Peripheral/advertising functionality will also fail to receive state updates.

### Finding 4: Dart authorize() throws UnsupportedError on Darwin
- **Location:** `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/lib/src/my_central_manager.dart:56-58`
- **Observation:** The `authorize()` method throws `UnsupportedError`:
  ```dart
  @override
  Future<bool> authorize() {
    throw UnsupportedError('authorize is not supported on Darwin.');
  }
  ```
- **Relevance:** The mesh service code at `bluetooth_mesh_service.dart:139` calls `await bleManager.central.authorize()` which will fail on macOS. However, this is inside a try-catch block so it's not the primary issue.

### Finding 5: State polling happens after delegate miss
- **Location:** `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/lib/src/my_central_manager.dart:300-320`
- **Observation:** After `_api.initialize()`, it calls `_getState()` which polls the current state:
  ```dart
  Future<void> _initialize() async {
    await Future(() async {
      try {
        await _api.initialize();
        _getState();  // This polls state AFTER missing the callback
      } catch (e) { ... }
    });
  }
  ```
- **Relevance:** This is a fallback to get current state, but it may have race conditions.

## Root Cause Analysis

**Primary Cause:** The lazy initialization fix for TCC broke the state management. When `CBCentralManager` is created, it immediately fires `centralManagerDidUpdateState`. The current code creates the manager without a delegate, then sets the delegate later. This causes the initial state callback to be lost.

**On CoreBluetooth:** When you create a `CBCentralManager`, the system immediately determines the Bluetooth state and calls the delegate's `centralManagerDidUpdateState` method. If no delegate is set at creation time, this callback is lost and never re-fired (unless Bluetooth state actually changes later).

**Confidence:** High

**Alternative hypotheses:**
1. The `_getState()` polling should work as a fallback, but there may be a race condition where the Dart side hasn't finished setting up listeners yet.
2. macOS sandbox restrictions could be blocking BLE access despite correct entitlements, but this is unlikely since entitlements appear correct.

## Recommended Fix

**Files to modify:**
1. `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/darwin/Classes/MyCentralManager.swift` (line 73-78)
2. `/Users/avillagran/Desarrollo/bitchat-flutter/packages/bluetooth_low_energy_bitchat/darwin/Classes/MyPeripheralManager.swift` (line 62-67)

**Steps:**

### Option A: Set delegate at creation time (Recommended)
Modify `getCentralManager()` to pass the delegate when creating CBCentralManager:

```swift
// MyCentralManager.swift
private func getCentralManager() -> CBCentralManager {
    if mCentralManager == nil {
        // CRITICAL: Pass delegate at creation to receive initial state callback
        mCentralManager = CBCentralManager(delegate: mCentralManagerDelegate, queue: nil)
    }
    return mCentralManager!
}
```

Similarly for `MyPeripheralManager.swift`:
```swift
private func getPeripheralManager() -> CBPeripheralManager {
    if mPeripheralManager == nil {
        mPeripheralManager = CBPeripheralManager(delegate: mPeripheralManagerDelegate, queue: nil)
    }
    return mPeripheralManager!
}
```

### Option B: Alternative - Poll state after delay
If Option A causes issues with the lazy initialization goal, add a state poll with delay after setting delegate:

```swift
func initialize() throws {
    let centralManager = getCentralManager()
    // ... cleanup code ...
    centralManager.delegate = mCentralManagerDelegate

    // Force state callback after delegate is set
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        guard let self = self else { return }
        self.mCentralManagerDelegate.centralManagerDidUpdateState(centralManager)
    }
}
```

### Verification after fix:
1. Run the app on macOS
2. Check console logs for `[BleManager] Central state changed: poweredOn`
3. Verify devices are discovered (look for `[GattClientManager] Connecting to` logs)

## Prevention

1. **Document CoreBluetooth timing requirements** - Add comments explaining that CBCentralManager/CBPeripheralManager must have delegates set at creation time or initial state callbacks are lost.

2. **Add integration tests** - Test BLE initialization flow to verify state callbacks are received.

3. **Add debug logging in Swift** - Add print statements in `centralManagerDidUpdateState` to verify callback is received:
   ```swift
   func centralManagerDidUpdateState(_ central: CBCentralManager) {
       print("[MyCentralManagerDelegate] State changed: \(central.state.rawValue)")
       mCentralManager.didUpdateState(central: central)
   }
   ```
