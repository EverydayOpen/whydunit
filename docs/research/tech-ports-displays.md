# Technical feasibility: diagnosing intermittent faults with ports, docks, displays, drives and power on macOS 14–27

*Researched 2026-09-27. The target is a non-sandboxed Developer ID app in Swift/SwiftUI, primarily for Apple silicon, with Intel as secondary.*

Confidence tags: **[V]** verified against a primary source (Apple header or doc, Apple open-source code, or shipping open-source code); **[L]** likely (one credible secondary source, or indirect evidence); **[U]** unverified (not confirmed; test it on real hardware before relying on it).

---

## 0. Bottom line

1. **Everything the app needs to observe can be read without root, a kernel or system extension, private entitlements or Full Disk Access.** IOKit registry reads, IOKit match/terminate/interest notifications, DiskArbitration, CoreGraphics display callbacks, NSWorkspace and IOPM sleep notifications, and `pmset -g log` all work from a normal user process. [V/L]
2. **The one gated source is the unified log**, which is where the **cause strings** are. Reading it (`OSLogStore.local()` or `/usr/bin/log show`) requires the **logged-in user to be an admin** and the app to be **non-sandboxed**. The app therefore has to degrade gracefully for standard users. [V]
3. **The key evidence for "which link failed, and how" is kernel log text, not IOKit.** When `AppleUSBHostPort::terminateDevice` destroys a device, the kernel logs a reason: `hardware connection lost` (the device was physically detached), `link change interrupt` (the device stayed attached but the link dropped), or `connect change interrupt` (seen on a hub port). The same line names the port that saw the event: a Mac root port such as `usb-drd2-port-ss@…` or a hub/dock port such as `AppleUSB20HubPort@…`. That split, "root port vs downstream hub port, and physical vs link", is exactly what a guided A/B test needs. **WhatPort and WhatCable do not read the unified log** (checked in their source). [V]
4. **Lifetime per-port counters already exist in IOKit and cost nothing to snapshot before and after a test.** They include `Overcurrent Count`, `Plug Event Count` and `ConnectionCount` on the USB-C port controller; `port-statistics` → `kPortStatConnectCount`, `kPortStatOverCurrentCount`, `kPortStatEnumerationFailureCount`, `kPortStatAddressFailureCount`, `kPortStatEOF2ViolationCount` and `kPortStatRemoteWakeCount` on root and hub ports; and the PD controller's `PortControllerHardResetCount`, `PortControllerDetachCount` and related counters in `AppleSmartBattery`. [V]
5. **Big caveat: none of these property keys are documented Apple API.** They are registry strings that Apple can rename. Two such renames have already happened: the `IOIOThunderboltSwitch*` → `IOThunderboltSwitch*` rename on M5 with macOS 26, and the root-port class rename between macOS 14 and 15. Plan for per-OS fallbacks and a fixture corpus. [V]
6. **Prior art to learn from:** `darrylmorley/whatcable` and `darrylmorley/whatport`, both MIT-licensed Swift code covering the same IOKit surface. Their free tiers are open source, and each has a Pro tier at **£9.99 one-time for 2 Macs** (WhatPort Pro "Flight Recorder"; WhatCable Pro per its README badge). The MIT licence allows you to reuse their code with attribution. [V]

---

## 1. Recommended data-source architecture

| Layer | Source | Needs | Gives |
|---|---|---|---|
| Live topology and state | IOKit registry reads with per-key `IORegistryEntryCreateCFProperty` | nothing (no root, no entitlement) | Port, transport, link speed and width, PD contract, display link, lifetime counters |
| Live events | `IONotificationPortCreate` + `IOServiceAddMatchingNotification` (`kIOFirstMatchNotification`/`kIOMatchedNotification`, `kIOTerminatedNotification`) + `IOServiceAddInterestNotification(kIOGeneralInterest)` | nothing | Device/port/transport arrival and removal, and property changes |
| Storage | DiskArbitration (`DASessionCreate`, `DARegisterDisk*Callback`) | nothing (no TCC prompt for metadata [L]) | Mount/unmount/disappear, and whether an unmount was graceful |
| Displays | `CGDisplayRegisterReconfigurationCallback`, `CGDisplayCopyDisplayMode`, IOKit `IOPortTransportStateDisplayPort` + `AppleCLCD2`/`IOMobileFramebufferShim` | nothing | Add/remove/mode changes, DP link rate, lanes, HPD, timing |
| Sleep/wake | `NSWorkspace` notifications, `IORegisterForSystemPower`, `pmset -g log` | nothing [L for pmset] | Sleep/wake timestamps and reasons, DarkWake |
| Power | `AppleSmartBattery` registry, `IOPortFeaturePowerSource`, `IOPSCopyExternalPowerAdapterDetails` | nothing (SMC user client is optional and blocked in the sandbox) | Charger watts, voltage and current, PDO menu, PD fault counters |
| **Cause text** | Unified log via `OSLogStore.local()` or `/usr/bin/log show --style ndjson` | **admin user + non-sandboxed** | `terminateDevice` reasons, APFS dangling mounts, storagekit, IOAccessoryManager transitions |

---

## 2. USB devices, root ports and hub ports (IOKit)

### 2.1 `IOUSBHostDevice` (one node per enumerated device; macOS 10.11+)
The keys below are the ones WhatCable reads from each `IOUSBHostDevice`, taken from its `USBWatcher.swift` [V]:

| Key | Type | Notes |
|---|---|---|
| `"idVendor"`, `"idProduct"` | NSNumber | VID and PID |
| `"locationID"` | NSNumber (UInt32) | Constant `kUSBHostPropertyLocationID` = `"locationID"` [V]. Each hub hop adds a nibble; one non-zero nibble means the device sits directly on a root port. |
| `"Device Speed"` | NSNumber | Enum: **0** Low 1.5 Mb/s, **1** Full 12 Mb/s, **2** High 480 Mb/s, **3** SuperSpeed 5 Gb/s, **4** SuperSpeed+ 10 Gb/s, **5** SuperSpeed+ Gen 2x2 20 Gb/s (per WhatCable `USBDevice.speedLabel`) [V] |
| `"USBSpeed"` | NSNumber | Constant `kUSBHostMatchingPropertySpeed` = `"USBSpeed"` [V]. It is a matching key, and it also appears in ioreg dumps [L]. |
| `"bcdUSB"`, `"bDeviceClass"` | NSNumber | |
| `"USB Product Name"`, `"USB Vendor Name"`, `"USB Serial Number"` | String | Constant names: `kUSBHostDevicePropertyProductString` = `"kUSBProductString"`, `kUSBHostDevicePropertyVendorString` = `"kUSBVendorString"`, `kUSBHostDevicePropertySerialNumberString` = `"kUSBSerialNumberString"` [V]. The human-readable keys above are what WhatCable reads. |
| `"Bus Power Available"`, `"Requested Power"` | NSNumber | WhatCable multiplies both by 2 to get mA [V] |
| `"USBPortType"` | NSNumber | `kUSBHostMatchingPropertyPortType` [V] |
| `"UsbPowerSinkAllocation"`, `"UsbPowerSinkCapability"`, `"kUSBFailedRequestedPower"` | | Constant strings [V]; semantics [U] |
| `"UsbIOPort"` (on the XHCI/port ancestry) | String (registry path) | `kUSBHostPortPropertyIOPortServicePath` = `"UsbIOPort"` [V]. On macOS 26+ it names the **physical** port (`Port-USB-C@5` vs `@6`). WhatCable prefers it over positional mapping because M1 desktops swap USB ports 1/2 and base M4/M5 skip `@3` [V] |

The Billboard class (`AppleUSBHostBillboardDevice`) exposes `UsbBillboardAltModeFailed`, `UsbBillboardCurrentMode`, `UsbBillboardPreferredMode`, `UsbBillboardSupportedModes` and `UsbBillboardVersion`. This is useful for "dock video alt-mode failed" [V: keys read by WhatCable].

### 2.2 Root-port and hub-port lifetime statistics (strong fault evidence)
- Classes: `AppleUSBHostPort` (base), plus `AppleUSB30XHCIPort`/`AppleUSB20XHCIPort` (concrete on macOS 14) and `AppleUSB*XHCIARMPort` (macOS 15+). Hub downstream ports are `AppleUSB20HubPort`/`AppleUSB30HubPort`. The Mac's own root ports are device-tree nodes named `usb-drdN-port-ss` / `-hs` [V: WhatPort `PortStatsReader.swift`].
- Property `"port-statistics"` (dictionary): `kPortStatConnectCount`, `kPortStatOverCurrentCount`, `kPortStatEnumerationFailureCount`, `kPortStatAddressFailureCount`, `kPortStatEOF2ViolationCount` (WhatPort labels this "linkErrorCount"), `kPortStatRemoteWakeCount` [V: WhatPort source; `kPortStatConnectCount`/`EnumerationFailure`/`RemoteWake` also appear in joevt's ioreg filter on MacRumors].
- **Hub-port `port-statistics` inside a dock is where a *downstream* overcurrent shows up.** That is the "USB Accessories Disabled" case. The Mac's own HPM `Overcurrent Count` is one step removed from it [V: WhatCable probe `40_hub_port_statistics.c` header].
- Also on ports: `"UsbHostPortOvercurrent"` (`kUSBHostPortPropertyOvercurrent`), `"kUSBDisconnectInterval"`, `"UsbCPortNumber"`, `"usb-port-number"`, `"port-status"`, `"UsbHostPortLinkSpeedLimit"` [V constant strings; runtime presence U].

---

## 3. USB-C port controllers on Apple silicon (HPM) and transports

### 3.1 Port-controller classes [V: WhatCable `HPMPortControllerClasses.swift`, corpus of 771+ machines]
- `AppleHPMInterfaceType10` (USB-C), `AppleHPMInterfaceType11` (MagSafe) and `AppleHPMInterfaceType12` (never observed) on M3-era and later Macs.
- `AppleHPMInterfaceType18` on MacBook Neo (A18 Pro).
- `AppleTCControllerType10` and `AppleTCControllerType11` on M1/M2.
- Catch-all superclass: `IOPort`. Keep only nodes whose `PortTypeDescription` is `"USB-C"` or starts with `"MagSafe"` **and** whose name starts with `Port-` (e.g. `Port-USB-C@1`).
- The **front USB-C ports on Mac mini and Mac Studio have no port-controller node.** They are plain USB behind an internal hub (WhatCable issue #291).
- **Intel Macs publish none of these.** Every Intel Mac in WhatCable's corpus has empty port-controller services [V].

### 3.2 Keys on the port node [V: `AppleHPMInterface.rawPropertyFallbackKeys`]
`PortType`, `PortTypeDescription`, `PortDescription`, `PortNumber`, **`ConnectionActive`**, `ActiveCable`, `OpticalCable`, `IOAccessoryUSBActive`, `IOAccessoryUSBSuperSpeedActive`, `IOAccessoryUSBModeType`, `IOAccessoryUSBConnectString`, **`TransportsSupported`**, **`TransportsActive`**, `TransportsProvisioned` (string arrays whose values include `"CC"`, `"USB2"`, `"USB3"`, `"USB4"`, `"CIO"` (Thunderbolt, "Converged I/O") and `"DisplayPort"`), `PlugOrientation`, **`Plug Event Count`**, **`ConnectionCount`**, **`Overcurrent Count`**, `Pin Configuration`, `DisplayPortPinAssignment`, `IOAccessoryPowerCurrentLimits`, `FW Version`, `Boot Flags`, `LDCM_StateDescription`, `FeaturesEnabled`, `IOAccessoryPowerMode`, `IOAccessoryActivePowerMode`.

**Interpretation warning (from WhatCable's corpus notes) [V]:** in 89.5% of 2,510 port readings, `Plug Event Count` is about 2 × `ConnectionCount`. It is **not a drop count**, and it rises when a device is unplugged at the *far* end of a cable that stays in the Mac. IOKit never records "a human did this". The guided test must therefore bracket a "hands-off" window.

### 3.3 Transport-state nodes (appear and disappear with the connection) [V]
`IOPortTransportStateCC`, `IOPortTransportStateUSB2`, `IOPortTransportStateUSB3`, `IOPortTransportStateCIO`, `IOPortTransportStateDisplayPort`, plus PD identity components `IOPortTransportComponentCCUSBPDSOP` / `…SOPp` / `…SOPpp` and the PHY classes `AppleTypeCPhy*`.
- Common keys: `Active`, `Tunneled`, `ParentPortType`, `ParentPortNumber`, `ParentBuiltInPortType`, `ParentBuiltInPortNumber`, `Priority`.
- USB3: `SuperSpeedSignaling`, `SuperSpeedSignalingDescription`, `DataRole`/`PortDataRole`.
- CIO: `CableGeneration`, `CableSpeed`.
- **Accessory security (TRM):** `TRM_State`, `TRM_StateDescription`, `TRM_TransportRestricted`, `TRM_TransportSupervised`, `TRM_DeviceLocked`, `TRM_Profile`, `TRM_GracePeriodReason`, `TRM_IdentificationRestricted`, `TRM_CacheMiss`, `TRM_RelaxedPeriod`. This is how you detect **"dock charges but no data/video because macOS blocked it"**.
- Apple documents the behaviour: on Apple-silicon laptops, new accessories must be allowed; **"Accessories can still charge… even if you choose Don't Allow"**, and if the Mac has been locked for 3 or more days you may need to unlock it before a previously allowed accessory works again ([support.apple.com/en-us/102282](https://support.apple.com/en-us/102282)). This is an important confounder to rule out before blaming a cable. [V]
- Liquid detection: class `AppleHPMLDCMType2`, keys `LiquidDetected`, `State`, `StateDescription`, `MeasurementStatus`, `MitigationsEnabled` (M3 and later) [V].

---

## 4. Thunderbolt / USB4
- **Switch classes:** match **both** `IOIOThunderboltSwitch` (older Macs, e.g. `IOIOThunderboltSwitchType5`) and `IOThunderboltSwitch` (M5 with macOS 26 ships `IOThunderboltSwitchType7` without the double-IO prefix). Observed subclasses: `Type3`, `Type5`, `Type7`, `IntelJHL8440`, `IntelJHL9580` [V: WhatCable `IOThunderboltSwitchWatcher.swift`].
- Switch keys: `Device Vendor Name`, `Device Model Name`, `Router ID`, `Depth`, `Route String`, `Max Port Number`, `Upstream Port Number`, `Vendor ID`, `Device ID`, `Firmware Version`, `Thunderbolt Version`, `UID`, `USB Port Map`, `DROM` [V].
- **Port children (`IOThunderboltPort`) [V]:** `Port Number`, `Adapter Type`, `Socket ID`, `Description`, **`Current Link Speed`**, **`Current Link Width`**, `Target Link Speed`, `Target Link Width`, `Supported Link Speed`, `Supported Link Width`, `Link Bandwidth`, `Maximum Bandwidth Allocated`, `Required Bandwidth Allocated`, `Buffer Allocation Request` {`Max USB3`, `Max PCIe`, `Max HI`, `Min DP Aux`}, `Max Credits`, `Dual-Link Port`, `Lane`, `CLx State`, `TRM Policy`, `Hop Table`, `PCI Path`.
- **Decoding** (on lane adapters only, `Adapter Type` = `0x000001`) [V: WhatCable `IOThunderboltLink.swift`, mirrors Linux `tb_regs.h`]:
  - `Current Link Speed`: `0x8` = 10 Gb/s per lane (TB3), `0x4` = 20 Gb/s per lane (USB4 v1 / TB4), `0x2` = 40 Gb/s per lane (USB4 v2 / TB5). `Supported Link Speed` is a bitmask of the same bits.
  - `Current Link Width` bitmask: `0x1` single, `0x2` dual, `0x4` asymmetric TX (3 TX / 1 RX), `0x8` asymmetric RX. `Target Link Width`: `0x1` single, `0x3` dual.
  - Adapter types: `0x0e0101` DP IN, `0x0e0102` DP OUT, `0x100101`/`0x100102` PCIe down/up, `0x200101`/`0x200102` USB3 down/up.
- **Fault signal:** a link that trains at a lower `Current Link Speed` or a narrower width than `Supported`, or that flaps between values, points at the cable or dock rather than at the device.
- `link-error-count` appears in ioreg output (joevt's filter) [L]; the class that carries it is [U].
- Intel Macs still publish the Thunderbolt fabric (WhatCable README) [V].

---

## 5. Power adapter / PD contract

### 5.1 `AppleSmartBattery` (Apple-silicon and Intel laptops) [V: WhatCable `AppleSmartBatteryReader.swift`]
- **`AdapterDetails`** (dictionary): `Watts`, **`AdapterVoltage`** (mV; *not* `Voltage`), `Current` (mA), `Description`, `AdapterPowerTier`, `IsWireless`, **`UsbHvcMenu`** (array of {`MaxVoltage`, `MaxCurrent`}, i.e. the charger's PDO menu), **`UsbHvcHvcIndex`** (the active entry), `FamilyCode`, `AdapterID`, `PMUConfiguration`, `Manufacturer`, `Name`, `Model` (a string such as `"0x7019"`), and in other dumps `SerialString`, `FwVersion`, `HwVersion`.
- **`PowerTelemetryData`** (macOS 13+ [L]): `SystemVoltageIn`, `SystemCurrentIn`, `SystemPowerIn`, `SystemLoad`, `BatteryPower`, `WallEnergyEstimate`, `AdapterEfficiencyLoss`, `SystemEnergyConsumed`, `PowerTelemetryErrorCount`, plus `Accumulated*` values and `*AccumulatorCount` counters.
- **`ChargerData`**: `ChargingVoltage`, `ChargingCurrent`, **`NotChargingReason`**, **`SlowChargingReason`**, `ChargerID`, **`ChargerResetCounter`**, **`ChargerInhibitReason`**, `TimeChargingThermallyLimited`, `VacVoltageLimit`. The meanings of the reason codes are [U].
- **`PortControllerInfo`** (array, one entry per port): `PortControllerActiveContractRdo`, `PortControllerPortPDO` (fixed 13-slot array), `PortControllerNPDOs`, `PortControllerMaxPower`, plus **fault counters**: `PortControllerAttachCount`, `PortControllerDetachCount`, **`PortControllerHardResetCount`**, `PortControllerDataRoleSwapFailCount`, `PortControllerPwrRoleSwapFailCount`, `PortControllerVdoFailCount`, **`PortControllerShortDetectCount`**, `PortControllerWakeFailCount`, `PortControllerWakeTimeoutCount`, `PortControllerStuckCmdCount`, `PortControllerI2cErrCount`, `PortControllerSrdoRejectCount`, `PortControllerInpFetEnFailCount`, and others.
- Top level: `ExternalConnected`, `IsCharging`, `Amperage`, `InstantAmperage`, `Voltage`, `AppleRawAdapterDetails`, `FedDetails` (`FedVendorID`, `FedProductID`, `FedPdSpecRevision`, …).

### 5.2 `IOPortFeaturePowerSource` (per port; Apple silicon) [V]
`PowerSourceName` (e.g. `"USB-PD"`, `"Brick ID"`, `"TypeC"`), `PowerSourceOptions` (**a CFSet, not an array**), `WinningPowerSourceOption`, with options {`Voltage (mV)`, `Max Current (mA)`, `Max Power (mW)`, `Class` = `IOPortFeaturePowerSourceOptionFixed`}, and parent linkage via `ParentBuiltInPortType`/`ParentBuiltInPortNumber`.

### 5.3 Public IOKit power-source API [V: Apple OSS `IOPowerSources.h`, `IOPSKeys.h`]
- `CFDictionaryRef IOPSCopyExternalPowerAdapterDetails(void)` with keys `kIOPSPowerAdapterIDKey` `"AdapterID"`, `kIOPSPowerAdapterWattsKey` `"Watts"`, `kIOPSPowerAdapterRevisionKey` `"AdapterRevision"`, `kIOPSPowerAdapterSerialNumberKey` `"SerialNumber"`, `kIOPSPowerAdapterFamilyKey` `"FamilyCode"`, `kIOPSPowerAdapterCurrentKey` `"Current"`, `kIOPSPowerAdapterSourceKey` `"Source"`. Every key "might not be defined".
- `IOPSNotificationCreateRunLoopSource(callback, ctx)`. notify(3) keys: `kIOPSNotifyPowerSource` = `"com.apple.system.powersources.source"` (AC ↔ battery changes; posted when AC is plugged or unplugged), `kIOPSNotifyTimeRemaining`, `kIOPSNotifyLowBattery`, and `kIOPSNotifyAttach` (*not* posted for AC plug/unplug).

### 5.4 SMC (optional, live per-port watts)
WhatCable/WhatPort open the `AppleSMC` user client (`IOServiceOpen`) and read keys **`PDTR`** (DC-in power), **`VD0R`**/**`ID0R`** (DC-in voltage and current) and **`PPBR`** (battery power). The keys are undocumented [L]. **The App Sandbox blocks this**, although the registry reads are unaffected ([WhatCable README](https://github.com/darrylmorley/whatcable)) [V].

---

## 6. External displays

### 6.1 `IOPortTransportStateDisplayPort` (Apple silicon) [V: WhatCable `DisplayPortTransportWatcher.swift`]
- **Link:** `Active`, **`LinkRate`**, **`LinkRateDescription`**, **`LaneCount`**, `MaxLaneCount`, `Tunneled`, **`HPD_State`**/`HPD_StateDescription`, `SinkCount`, **`DriverStatus`**/`DriverStatusDescription`, `Role`, `TransportType`, `EDID` (raw bytes), `EDIDChanged`, `NominalSignalingFrequenciesHz`, `Index`, and `Metadata` {`ProductName`, `ManufacturerName`, `SerialNumber`, `BranchDeviceOUI`, `BranchDeviceID`, …}.
- DisplayPort branch/converter information: `DFP Type`/`DFP Type Description`. HDCP-ish status: `AuthenticationStatus*`, `AuthorizationStatus*`, `HashStatus*`.
- **`LinkRate` codes** (corpus-confirmed 1–4): `1` = "1.62 Gbps (RBR)", `2` = "2.7 Gbps (HBR)", `3` = "5.4 Gbps (HBR2)", `4` = "8.1 Gbps (HBR3)". Codes 5–7 (UHBR10/13.5/20) have not yet been seen in the corpus [U]. Prefer parsing `LinkRateDescription`.
- **Fault signals:** an `HPD_State` toggle means the sink dropped hot-plug. A `LinkRate` or `LaneCount` that falls on re-train means marginal signal integrity (cable, dock or adapter).

### 6.2 Display timing node [V: WhatCable `DisplayTimingReader.swift`]
- Classes: **`AppleCLCD2`** (M1 family, M2, M3) and **`IOMobileFramebufferShim`** (M2 Pro/Max/Ultra, M3 Pro/Max, all M4/M5). The split is by chip, not by macOS version.
- Keys: `DisplayAttributes` → `ProductAttributes` (`SerialNumber`, `LegacyManufacturerID`, ProductID …), `DPTimingModeId`, `TimingElements`/`PreferredTimingElements` (`HorizontalAttributes`/`VerticalAttributes` with `Active`, `Total`, `PreciseSyncRate` (16.16 fixed point), `IsInterlaced`, `ColorModes` [{`PixelEncoding`, `Depth`, `SupportsDSC`, `IsVirtual`, `DownstreamFormat`}]), `ValidPixelEncodings`, `DSCRequiredColorElementIDs`, `UnsafeColorElementIDs`, `EDID UUID`/`IOMFBUUID` (the join key back to the DP node's EDID), and `external`.
- On Apple silicon, `AlphanumericSerialNumber` and `ManufacturerID` are absent. Use `SerialNumber` and `LegacyManufacturerID`, and get the full EDID from the transport node ([reportmate issue #95](https://github.com/reportmate/reportmate-client-mac/issues/95)) [L].

### 6.3 CoreGraphics (public API) [V: Apple docs]
- `CGDisplayRegisterReconfigurationCallback(_:_:)`. The callback fires **twice per display** (before and after). `CGDisplayChangeSummaryFlags` members: `.beginConfigurationFlag`, `.movedFlag`, `.setMainFlag`, `.setModeFlag`, `.addFlag`, `.removeFlag`, `.enabledFlag`, `.disabledFlag`, `.mirrorFlag`, `.unMirrorFlag`, `.desktopShapeChangedFlag`.
- `CGGetOnlineDisplayList`, `CGDisplayCopyDisplayMode` (`.pixelWidth`, `.pixelHeight`, `.refreshRate`), `CGDisplayIsBuiltin`, `CGDisplayVendorNumber`/`ModelNumber`/`SerialNumber`, `CGDisplayIsAsleep`. `CGDisplayIOServicePort` is deprecated, so map CG display to IOKit via EDID vendor/model/serial.
- Intel: `IOFramebuffer`/`IODisplayConnect` with `IODisplayEDID` [U: not re-verified in this pass].

---

## 7. External drives: detecting an unexpected (non-user) eject

**What Apple's own code does** (Apple OSS `diskarbitrationd/DAServer.c`) [V]: when a disk disappears, `diskarbitrationd` shows **"Disk Not Ejected Properly"** only if the disk still had `kDADiskDescriptionVolumePathKey`, was `VolumeMountable`, had `MediaWritable == true`, and was not mounted `MNT_RDONLY`. The strings live in `DiskArbitrationAgent/DADialog.m`: title `"Disk Not Ejected Properly"`, body `"Eject \"%@\" before disconnecting or turning it off."`.

**Graceful vs surprise removal** ([Bombich, 2026-07-07](https://bombich.com/blog/2026/07/07/disk-not-ejected-properly)) [V]: a graceful unmount always offers clients a chance to dissent via DiskArbitration, and the IOKit objects stay. A surprise removal sends **no dissent request**, and all IOMedia objects are terminated at once. So:

- `DARegisterDiskUnmountApprovalCallback`: record "a graceful unmount was requested" for that BSD name. Return `nil` so you never block it.
- `DARegisterDiskDisappearedCallback` (or losing `VolumePath` via `DARegisterDiskDescriptionChangedCallback`) **without** a preceding approval request means an **unexpected removal**. Then join to the kernel log reason (§9) and to the USB/TB terminate event from the same second.
- Useful description keys [V: `DADisk.h`]: `kDADiskDescriptionVolumePathKey`, `…VolumeNameKey`, `…VolumeUUIDKey`, `…MediaBSDNameKey`, `…MediaWritableKey`, `…MediaRemovableKey`, `…MediaWholeKey`, `…DeviceProtocolKey`, `…DeviceInternalKey`, `…DevicePathKey` (the IOKit path, used to join to IOUSBHostDevice or TB), `…BusPathKey`, `…DeviceModelKey`, `…DeviceVendorKey`. Scheduling: `DASessionSetDispatchQueue` (10.7+).
- Reading or writing files on the external volume (e.g. a sustained-I/O stress step) triggers the **Removable Volumes** TCC prompt the first time, unless the user picked the file or volume in an Open panel ([Apple wording quoted on MacRumors](https://forums.macrumors.com/threads/how-do-i-allow-access-to-removable-volumes.2376842/)) [L]. Metadata via DiskArbitration/IOKit does not prompt [L].

---

## 8. Event plumbing: Swift snippets (macOS 14+)

### 8.1 IOKit match/terminate plus property-change interest
```swift
import IOKit
import Foundation

/// Per-key read. The bulk IORegistryEntryCreateCFProperties can abort inside IOCFUnserializeBinary
/// when a service is torn down mid-read (WhatCable issue #181), so read keys one at a time.
func prop<T>(_ s: io_service_t, _ key: String) -> T? {
    IORegistryEntryCreateCFProperty(s, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? T
}
func entryID(_ s: io_service_t) -> UInt64 { var id: UInt64 = 0; IORegistryEntryGetRegistryEntryID(s, &id); return id }

final class IOWatch {
    final class Reg { let kind: String, cls: String, h: (String, String, io_service_t) -> Void
        init(_ k: String, _ c: String, _ h: @escaping (String, String, io_service_t) -> Void) { kind = k; cls = c; self.h = h } }
    private let port = IONotificationPortCreate(kIOMainPortDefault)!
    private var regs: [Reg] = []; private var iters: [io_iterator_t] = []

    init() { IONotificationPortSetDispatchQueue(port, .main) }

    /// kinds: kIOFirstMatchNotification / kIOMatchedNotification / kIOTerminatedNotification
    func watch(_ cls: String, _ kinds: [String], _ h: @escaping (String, String, io_service_t) -> Void) {
        for kind in kinds {
            let r = Reg(kind, cls, h); regs.append(r)
            var it: io_iterator_t = 0
            let cb: IOServiceMatchingCallback = { ctx, it in
                let r = Unmanaged<IOWatch.Reg>.fromOpaque(ctx!).takeUnretainedValue()
                while case let s = IOIteratorNext(it), s != 0 { r.h(r.kind, r.cls, s); IOObjectRelease(s) }
            }
            // IOServiceMatching() is consumed per call: create a fresh one each time.
            guard IOServiceAddMatchingNotification(port, kind, IOServiceMatching(cls), cb,
                                                   Unmanaged.passUnretained(r).toOpaque(), &it) == KERN_SUCCESS else { continue }
            iters.append(it)
            while case let s = IOIteratorNext(it), s != 0 { h(kind, cls, s); IOObjectRelease(s) } // arm + initial set
        }
    }
    /// Property changes (e.g. ConnectionActive, TransportsActive, HPD) do NOT fire match notifications.
    final class Box { let h: (UInt32) -> Void; init(_ h: @escaping (UInt32) -> Void) { self.h = h } }
    func interest(_ s: io_service_t, _ h: @escaping (UInt32) -> Void) -> io_object_t {
        let box = Unmanaged.passRetained(Box(h)) // ponytail: leaked per port; release when the port terminates if ports churn
        var n: io_object_t = 0
        IOServiceAddInterestNotification(port, s, kIOGeneralInterest, { ctx, _, msg, _ in
            Unmanaged<IOWatch.Box>.fromOpaque(ctx!).takeUnretainedValue().h(msg) // 0xE0000130 = kIOMessageServicePropertyChange
        }, box.toOpaque(), &n)
        return n
    }
}
// Usage: record entryID at match time; the terminated object can no longer be queried reliably.
// w.watch("IOUSBHostDevice", [kIOFirstMatchNotification, kIOTerminatedNotification]) { kind, cls, s in ... }
// Also watch: "IOPortTransportStateDisplayPort", "IOPortTransportStateUSB3", "IOPortTransportStateCIO",
// "IOThunderboltSwitch", "IOIOThunderboltSwitch", "IOPortFeaturePowerSource", "AppleHPMInterfaceType10", "AppleTCControllerType10", …
```
Gotcha [V: WhatCable `IOKitHelpers.swift`]: on macOS 26, `IOIteratorIsValid` returns false for an iterator that matched nothing, so only retry (`IOIteratorReset`) when the pass had already produced items.

### 8.2 DiskArbitration: unexpected-removal detector
```swift
import DiskArbitration

final class DiskWatch {
    let session = DASessionCreate(kCFAllocatorDefault)!
    var mounted: [String: String] = [:]      // bsd -> volume path
    var graceful: Set<String> = []           // bsd names with an unmount request
    var onSurprise: (String, String) -> Void = { _, _ in }

    static func bsd(_ d: DADisk) -> String? { DADiskGetBSDName(d).map { String(cString: $0) } }
    static func path(_ d: DADisk) -> String? {
        ((DADiskCopyDescription(d) as? [String: Any])?[kDADiskDescriptionVolumePathKey as String] as? URL)?.path
    }
    static func me(_ c: UnsafeMutableRawPointer?) -> DiskWatch { Unmanaged<DiskWatch>.fromOpaque(c!).takeUnretainedValue() }
    func start() {
        DASessionSetDispatchQueue(session, .main)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(session, nil, { d, c in
            let w = DiskWatch.me(c); if let b = DiskWatch.bsd(d), let p = DiskWatch.path(d) { w.mounted[b] = p } }, ctx)
        DARegisterDiskDescriptionChangedCallback(session, nil, nil, { d, _, c in
            let w = DiskWatch.me(c); guard let b = DiskWatch.bsd(d) else { return }
            if let p = DiskWatch.path(d) { w.mounted[b] = p; w.graceful.remove(b) }
            else if let p = w.mounted.removeValue(forKey: b), !w.graceful.contains(b) { w.onSurprise(b, p) } }, ctx)
        DARegisterDiskUnmountApprovalCallback(session, nil, { d, c in
            if let b = DiskWatch.bsd(d) { DiskWatch.me(c).graceful.insert(b) }; return nil }, ctx)   // nil = approve
        DARegisterDiskDisappearedCallback(session, nil, { d, c in
            let w = DiskWatch.me(c); guard let b = DiskWatch.bsd(d) else { return }
            if let p = w.mounted.removeValue(forKey: b), !w.graceful.contains(b) { w.onSurprise(b, p) }
            w.graceful.remove(b) }, ctx)
    }
}
// ponytail: heuristic derived from DAServer.c plus Bombich's observations. Validate on hardware
// (Finder eject, `diskutil eject`, cable pull, drive firmware reset, sleep/wake) before shipping.
```

### 8.3 Displays, sleep/wake, power source
```swift
import AppKit
import IOKit.pwr_mgt
import IOKit.ps

CGDisplayRegisterReconfigurationCallback({ id, f, _ in
    guard !f.contains(.beginConfigurationFlag) else { return }       // ignore the "before" pass
    if f.contains(.removeFlag) { /* display id removed */ }
    if f.contains(.addFlag)    { /* display id added */ }
}, nil)

let ws = NSWorkspace.shared.notificationCenter                          // must be the workspace center (QA1340)
for n in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
          NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
          NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
    ws.addObserver(forName: n, object: nil, queue: .main) { _ in /* timestamp it */ }
}

// IORegisterForSystemPower: kIOMessage* are function-like macros, so they are not imported into Swift. Values
// come from xnu IOMessage.h: iokit_common_msg(x) = 0xE0000000 | x.
let kCanSystemSleep: UInt32 = 0xE000_0270, kWillSleep: UInt32 = 0xE000_0280,
    kHasPoweredOn: UInt32 = 0xE000_0300, kWillPowerOn: UInt32 = 0xE000_0320
var gRootPort: io_connect_t = 0; var gPMPort: IONotificationPortRef?; var gPMNotifier: io_object_t = 0
gRootPort = IORegisterForSystemPower(nil, &gPMPort, { _, _, type, arg in
    if type == kCanSystemSleep || type == kWillSleep { IOAllowPowerChange(gRootPort, Int(bitPattern: arg)) } // must ack within 30 s
}, &gPMNotifier)
IONotificationPortSetDispatchQueue(gPMPort, .main)

let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
let watts = adapter?[kIOPSPowerAdapterWattsKey] as? Int
if let src = IOPSNotificationCreateRunLoopSource({ _ in /* AC<->battery or source changed */ }, nil)?.takeRetainedValue() {
    CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
}
```

---

## 9. Unified log: the cause strings

### 9.1 Verified message shapes
| Message (sender in parentheses) | Meaning | Source |
|---|---|---|
| `kernel: (IOUSBHostFamily) usb-drd2-port-ss@02200000: AppleUSBHostPort::terminateDevice: destroying 0x2eb9/9211/3100 (Rocket XTRM Q): hardware connection lost` then `AppleUSBHostPort::cableChangeOccurred: powering off` | The device was **physically detached** at that port | [Bombich 2026](https://bombich.com/blog/2026/07/07/disk-not-ejected-properly) [V] |
| `… AppleUSBHostPort::terminateDevice: destroying … : link change interrupt` | The device **stayed attached** but its link dropped (firmware crash or reset, hub reset, signal integrity) | Bombich [V] |
| `kernel: (IOUSBHostFamily) AppleUSB20HubPort@01110000: AppleUSBHostPort::terminateDevice: destroying 0xabcd/1234/0100 (UDisk): connect change interrupt` | A drive pulled from a **hub** port (the event is seen at the hub, not the root port) | [MacRumors 2022 log](https://forums.macrumors.com/threads/where-are-the-log-entries-for-improper-disks-disconnections.2352143/) [V] |
| `kernel: (IOAccessoryManager) IOPortTransportState::handleStateChange(): [Port-USB-C@3: USB2] Handling state change...` | A transport on a physical USB-C port changed state | Bombich [V] (the DisplayPort/CIO variants [U]) |
| `kernel: (apfs) dangling_mount_callback…: Found dangling mount /dev/disk9s2`; `apfs_vfsop_unmount… failed to finish all transactions before unmount! (err 6)` | A mounted volume vanished, so data loss was possible | Bombich [V] |
| `storagekitd: [com.apple.storagekit:general] -[SKDaemonManager(DiskNotifications) addDisappearedDisk:] … Mounted: Yes` | This leads to the "Disk Not Ejected Properly" alert | Bombich [V] |
| `diskarbitrationd: [com.apple.DiskArbitration.diskarbitrationd:default] removed disk, id = /dev/disk5s1.` / `… kind = disk disappeared …` | DA-level removal | MacRumors [V] |
| `AppleUSBHostPort::interruptOccurred: overcurrent detected with port status 0x4000` | Over-current on a USB port | [Apple Community 7435668](https://discussions.apple.com/thread/7435668) (2016, Intel era) [L]; on Apple silicon prefer the counters in §2.2 and §3.2 |

**Localization rule for the A/B engine:** the node name in the `terminateDevice` line tells you where the break was.
- A **root port** (`usb-drdN-port-ss|hs@…`) losing the dock's own hub means the Mac↔dock segment or the dock's power failed.
- Only **`AppleUSB*HubPort@…`** entries under the dock means the dock↔device segment or the device failed.

The user alert for power problems is **"USB Devices Disabled"** ([support.apple.com/en-us/102204](https://support.apple.com/en-us/102204)). The exact wording in current macOS versions [U].

### 9.2 Reading the log
- **`OSLogStore.local()`**: Apple docs say "The caller must be run by an admin account and have the `com.apple.logging.local-store` entitlement". In practice (Quinn/DTS via [mjtsai](https://mjtsai.com/blog/2021/12/10/oslogstore-on-monterey/)), **admin is enough on macOS 12+ for non-sandboxed apps**. The entitlement is not obtainable by third parties, and **sandboxed apps fail** ("Connection to logd failed"; [Quinn, Jan 2024](https://developer.apple.com/forums/thread/744806)). [V]
  - API: `store.position(date:)`, `position(timeIntervalSinceEnd:)`, `position(timeIntervalSinceLatestBoot:)`, `getEntries(with:at:matching:)`.
  - Cast entries to `OSLogEntryLog` for `level`, `subsystem`, `category`, `process`, `processIdentifier`, `sender`, `composedMessage` [V].
  - NSPredicate keys known to work: `subsystem`, `composedMessage` (`messageType` has quirks with `IN`) ([SO 79364678](https://stackoverflow.com/questions/79364678/)) [L]. Filter `process`/`sender` in Swift if the predicate rejects them [U].
  - Cap result counts: Howard Oakley warns that unbounded queries "blow up" [V].
- **CLI fallback** (also admin-only; a standard user gets refused unless `sudo` is configured, per [Der Flounder 2026-01-17](https://derflounder.wordpress.com/2026/01/17/enabling-a-standard-user-account-to-access-the-unified-system-log-on-macos-using-the-log-command-line-tool/)) [V]:
  ```
  /usr/bin/log show --style ndjson --start "2026-09-27 10:00:00" --end "2026-09-27 10:40:00" \
    --predicate 'process == "kernel" AND (sender == "IOUSBHostFamily" OR sender == "IOAccessoryManager" OR sender == "apfs" OR sender == "IOUSBMassStorageDriver" OR sender == "IOThunderboltFamily") OR process == "storagekitd" OR process == "diskarbitrationd"'
  ```
  `--style` accepts `default|compact|json|ndjson|syslog`. Predicate fields: `eventMessage`, `eventType`, `messageType`, `process`, `processImagePath`, `sender`, `senderImagePath`, `subsystem`, `category` ([ss64 log](https://ss64.com/mac/log.html)) [V]. The `IOThunderboltFamily` sender name [U].
- Detect admin before offering the log-based "cause" features. For example, check membership of group 80 (`admin`), which is what Eclectic Light's apps do [V]. Otherwise fall back to IOKit-only evidence.
- Private data appears as `<private>` (e.g. the `usbpowerd: terminated <private>` line) [V]. Do not depend on redacted fields.

---

## 10. `pmset -g log`: sleep, wake and DarkWake
Verified line shapes ([Ask Different 446849](https://apple.stackexchange.com/questions/446849/)) [V]:
```
2022-09-09 02:33:24 +0300 DarkWake              DarkWake from Deep Idle [CDN] : due to EC.Bluetooth/Maintenance Using BATT (Charge:90%) 7 secs
2022-09-09 02:33:31 +0300 Sleep                 Entering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using Batt (Charge:90%) 3 secs
```
Other observed forms: `DarkWake from Standby [CDN] : due to …`, `DarkWake from Deep Idle [CDNPB] : due to NUB.SPMISw3IRQ …` (M1 Max, Reddit), `Entering Sleep state due to 'Clamshell Sleep'`, `'Idle Sleep'`, `'Software Sleep pid=121'`. The event types include `Sleep`, `Wake`, `DarkWake`, `Wake Requests` and `Assertions` [L].

```swift
// ponytail: regex validated only against the sample lines above; extend when real dumps show new shapes.
let line = #/^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d [+-]\d{4}) (\S+(?: \S+)?)\s{2,}(.*)$/#
let reason = #/due to (?:'([^']+)'|(\S+))/#
let s = "2022-09-09 02:33:24 +0300 DarkWake              DarkWake from Deep Idle [CDN] : due to EC.Bluetooth/Maintenance Using BATT (Charge:90%) 7 secs"
let m = s.wholeMatch(of: line)!
assert(m.2 == "DarkWake" && m.3.firstMatch(of: reason)?.output.2 == "EC.Bluetooth/Maintenance")
```
Run `pmset -g log` without sudo [L]. It is useful for "dock or drive dropped on every DarkWake" correlation: join by timestamp to IOKit terminate events.

---

## 11. `system_profiler` datatypes (use as a cross-check, not the primary source)
Spawning it is slow (seconds). Prefer IOKit. Command form: `system_profiler -json SPThunderboltDataType SPDisplaysDataType SPPowerDataType`.

| Datatype | Status / keys |
|---|---|
| **`SPUSBDataType`** | **Removed/empty on macOS 26 Tahoe** ([SO 79775991](https://stackoverflow.com/questions/79775991/), [Apple Community 256180514](https://discussions.apple.com/thread/256180514)) [V]. |
| **`SPUSBHostDataType`** | The replacement on macOS 26 and later. Text output has device fields `Link Speed`, `USB Vendor ID`, `USB Product ID`, `Location ID`, `Power Allocated`, `Power Sink Capability`, `Current Required (mA)`, `Current Available (mA)` (per the `usbi` Go parser) [L]. One Apple Community user reports it shows only host controllers, which conflicts with the other sources [U]. JSON key names [U]. |
| **`SPThunderboltDataType`** | Items have `_name`, `device_name_key`, `vendor_name_key`, `receptacle_N_tag` {`current_speed_key` (e.g. `"Up to 40 Gb/s"`), `receptacle_status_key` (`"receptacle_connected"` / `"receptacle_no_devices_connected"`), `link_status_key` (hex such as `"0x100"`)}, and `_items` for downstream devices ([cablescope](https://github.com/tzzs/cablescope) tests from macOS 26/M4) [L]. `current_link_width_key` appears in older XML [L]. |
| **`SPDisplaysDataType`** | GPU items (`sppci_model`) → `spdisplays_ndrvs` [{`_name`, `_spdisplays_displayID`, `spdisplays_pixelresolution`, …}] [L]. Older keys `_spdisplays_pixels` and `spdisplays_resolution` (Jamf) [L]. **No DP link-rate key was found on built-in-only machines**; a `spdisplays_link_rate` value such as `"spdisplays_hbr3"` [U]. `spdisplays_ndrvs` is **empty when no console user is logged in** (so do not call it from a LaunchDaemon) [L]. |
| **`SPPowerDataType`** | Item keys `sppower_battery_charge_info`, `sppower_battery_health_info`, `sppower_battery_model_info`, `sppower_ups_installed`. Charger item: `sppower_ac_charger_watts`, `sppower_battery_charger_connected`, `sppower_battery_is_charging`, `sppower_ac_charger_ID`, `sppower_ac_charger_name`, `sppower_ac_charger_manufacturer`, `sppower_ac_charger_serial_number`, `sppower_ac_charger_hardware_version`, `sppower_ac_charger_firmware_version` ([bynkii 2025](https://bynkiidotcom.wordpress.com/2025/01/26/grabbing-system_profiler-data-in-powershell/)) [L]. |
| `SPStorageDataType`, `SPNVMeDataType` | JSON keys [U]. Use DiskArbitration plus the IOKit `Protocol Characteristics` instead. |

---

## 12. Sandbox, TCC and privilege matrix

| Capability | Developer ID, non-sandboxed | App Sandbox (MAS) |
|---|---|---|
| IOKit registry reads (all §2–§6 keys) | Yes | **Yes**: "the IOKit registry reads come back identical either way" (WhatCable README, tested) [V] |
| IOKit match/interest notifications | Yes | Yes [L] |
| SMC user client (`IOServiceOpen("AppleSMC")`) | Yes | **Blocked** [V] |
| `OSLogStore.local()` / `log show` | **Admin user only** | **No** ("Connection to logd failed") [V] |
| Spawning `system_profiler` / `pmset` / `log` | Yes | The child inherits the sandbox; results [U] |
| DiskArbitration metadata | Yes | [U] |
| File I/O on external volumes | TCC "Removable Volumes" prompt [L] | Also needs a user-selected file or bookmark [L] |
| Full Disk Access | **Not needed** for any of the above [L] | n/a |
| Root / privileged helper | **Not needed** | n/a |

Conclusion: ship Developer ID and notarized; the Mac App Store would lose log-based cause detection and SMC wattage. Use no special entitlements. Hardened runtime does not affect IOKit reads [L].

---

## 13. Version and platform notes (macOS 14 → 27)
- **macOS 14 → 15:** root-port classes `AppleUSB*XHCIPort` → `AppleUSB*XHCIARMPort` subclasses. Match the base `AppleUSBHostPort` [V].
- **macOS 14/15:** `UsbIOPort` path absent, so port attribution falls back to walking to `hpm<N>`/`atc<N>`/`usb-drd<N>` ancestors [V].
- **macOS 26:** `SPUSBDataType` removed [V]. `IOThunderboltSwitchType7` (no `IOIO` prefix) on M5 [V]. `IOIteratorIsValid` is false for empty matches [V]. `UsbIOPort` names the physical port [V].
- **macOS 27.0:** WhatCable's customer-probe corpus already contains `m5pro_macos27.0_*`, `m3pro_macos27.0_l` and `m4_macos27.0_c` folders parsed by the same readers. This indicates the HPM, Thunderbolt and USB classes and keys persist in 27.0 [L]. The "Golden Gate" name and any 27.x IOKit changes [U].
- **Intel (last supported by macOS 26, per the brief [U]):** there are no HPM, `AppleTypeCPhy`, `IOPortTransportState*` or `IOPortFeaturePowerSource` nodes [V]. Available: `IOUSBHostDevice`, root-port `port-statistics` (macOS 14 classes), the Thunderbolt fabric (`IOThunderboltSwitchIntelJHL*`), `AppleSmartBattery AdapterDetails`, CG and DA. Expect "reduced detail" on Intel, as WhatPort and WhatCable do.

---

## 14. Signal matrix for the guided A/B diagnosis

| Suspected fault | Primary evidence (IOKit, no admin) | Cause evidence (log, admin) |
|---|---|---|
| Cable or connector at the Mac | HPM `Plug Event Count`/`ConnectionCount` delta during a hands-off window; root port `kPortStatConnectCount` delta; TB `Current Link Speed/Width` below `Supported` | `terminateDevice … hardware connection lost` + `cableChangeOccurred: powering off` on `usb-drdN-port-*` |
| Dock internal reset or firmware | Every device behind the dock terminates at the same second; the dock hub's `IOUSBHostDevice` re-enumerates | `link change interrupt` on the root port for the dock hub |
| Device firmware crash (SSD) | Only that device terminates, then reappears within seconds (Bombich: about 3 s) | `link change interrupt` for that device only; APFS dangling mount |
| Downstream over-current (bus-powered device on a dock) | Hub-port `port-statistics.kPortStatOverCurrentCount` rises | "USB Devices Disabled" alert; `overcurrent` kernel text [L] |
| Mac-port over-current | HPM `Overcurrent Count`, root-port `kPortStatOverCurrentCount` | |
| Charging drop-outs | `PortControllerHardResetCount`/`DetachCount` rises; `ChargerResetCounter`; `NotChargingReason`; `WinningPowerSourceOption` changes; `IOPSNotify` source flips | |
| Display blanking | DP `HPD_State` toggles; `LinkRate`/`LaneCount` drop on retrain; CG `.removeFlag`/`.addFlag` pair; `DriverStatus` changes | `IOPortTransportState::handleStateChange … DisplayPort` [U] |
| Accessory blocked (not a hardware fault) | `TRM_TransportRestricted == true`, `TRM_DeviceLocked` | |
| Sleep/wake-induced drops | Terminate events within N seconds after `didWake`/DarkWake | `pmset -g log` DarkWake reasons |

**Protocol:** snapshot all counters, then run a timed hands-off window (and optionally one sleep/wake cycle), snapshot again and compute deltas. Change **one** variable at a time (direct vs dock, port A vs B, cable X vs Y) and compare event rates over equal durations. Always show a "not proof of cause" disclaimer when counts are low.

---

## 15. Building and testing from Windows via GitHub Actions
- GitHub's macOS runners are VMs with **no physical USB-C, Thunderbolt or display hardware**, so the HPM, Thunderbolt and DP nodes will be absent [L]. CI can compile, sign and notarize, but it **cannot exercise the readers**.
- Design every reader as a pure function over `(String) -> Any?` (the WhatCable pattern) so unit tests run on **fixtures**. Capture those fixtures with `ioreg -a` (XML plist output, parseable on Windows too) [V flags per the `ioreg(8)` man page]:
  ```
  ioreg -a -l -w0 -r -c AppleHPMInterfaceType10      > hpm.plist
  ioreg -a -l -w0 -r -c AppleTCControllerType10      > tc.plist
  ioreg -a -l -w0 -r -c IOPortTransportStateDisplayPort > dp.plist
  ioreg -a -l -w0 -r -c IOThunderboltPort            > tbport.plist
  ioreg -a -l -w0 -r -c AppleUSBHostPort             > usbports.plist
  ioreg -a -l -w0 -r -c IOUSBHostDevice              > usbdev.plist
  ioreg -a -l -w0 -r -c AppleSmartBattery            > battery.plist
  pmset -g log > pmset.txt
  log show --style ndjson --last 30m --predicate 'process == "kernel"' > kernel.ndjson
  ```
- You still need **real Apple-silicon hardware** (plus at least one dock, one TB/USB4 cable, a bus-powered SSD and a DP monitor) to validate the event semantics. That validation is the main schedule risk, not the code.

---

## 16. Unverified items to test on hardware first
1. `OSLogStore` NSPredicate support for `process`/`sender`, and OSLogStore performance over hours of history.
2. The kernel log wording for Thunderbolt disconnects and DP link-training failures, and whether `IOThunderboltFamily` is the `sender` name.
3. DP `LinkRate` codes 5–7 (UHBR).
4. `SPUSBHostDataType` JSON keys, and whether it lists devices on every 26.x/27.x build.
5. The DiskArbitration surprise-removal heuristic across Finder eject, `diskutil eject`, cable pull, drive firmware reset and sleep.
6. Meanings of `NotChargingReason`, `SlowChargingReason`, `ChargerInhibitReason` and the `TRM_State` codes.
7. Whether `pmset -g log` and `system_profiler` run for standard (non-admin) users on 26/27.
8. Anything specific to macOS 27 ("Golden Gate") beyond WhatCable's corpus evidence.
9. The current macOS wording of the over-current alert ("USB Devices Disabled" vs "Accessories Need Power").

## Sources
- WhatCable source (MIT): https://github.com/darrylmorley/whatcable (files cited: `HPMPortControllerClasses.swift`, `AppleHPMInterface.swift`, `USBWatcher.swift`, `USBDevice.swift`, `IOThunderboltSwitchWatcher.swift`, `IOThunderboltLink.swift`, `AppleSmartBatteryReader.swift`, `PowerSourceWatcher.swift`, `DisplayPortTransportWatcher.swift`, `DisplayTimingReader.swift`, `DisplayDiagnostic.swift`, `TRMTransportWatcher.swift`, `LiquidDetectionWatcher.swift`, `SMCPowerReader.swift`, `IOKitHelpers.swift`, `ConnectionDiagnostic.swift`, `probes/test-kit/40_hub_port_statistics.c`, README)
- WhatPort source (MIT): https://github.com/darrylmorley/whatport (`PortStatsReader.swift`, README; Pro £9.99) · https://www.whatport.app/
- cablescope: https://github.com/tzzs/cablescope
- IOUSBHostFamilyDefinitions constants (objc2 mirror of the Apple header): https://docs.rs/objc2-io-kit/latest/src/objc2_io_kit/generated/usb/IOUSBHostFamilyDefinitions.rs.html
- Apple OSS IOKitUser `IOPSKeys.h` / `IOPowerSources.h`: https://github.com/apple-oss-distributions/IOKitUser
- Apple OSS DiskArbitration (`DAServer.c`, `DADialog.m`, headers): https://github.com/apple-oss-distributions/DiskArbitration
- xnu `IOMessage.h`: https://github.com/apple-oss-distributions/xnu/blob/main/iokit/IOKit/IOMessage.h
- Apple QA1340 (sleep/wake): https://developer.apple.com/library/archive/qa/qa1340/_index.html
- Apple docs: CGDisplayChangeSummaryFlags https://developer.apple.com/documentation/coregraphics/cgdisplaychangesummaryflags · OSLogStore.local() https://developer.apple.com/documentation/oslog/oslogstore/local() · NSWorkspace https://developer.apple.com/documentation/appkit/nsworkspace
- Allow accessories to connect: https://support.apple.com/en-us/102282 · USB Devices Disabled: https://support.apple.com/en-us/102204
- Bombich, "Disk Not Ejected Properly" (2026-07-07): https://bombich.com/blog/2026/07/07/disk-not-ejected-properly
- MacRumors improper-disconnect log lines: https://forums.macrumors.com/threads/where-are-the-log-entries-for-improper-disks-disconnections.2352143/
- joevt ioreg filter (kPortStat keys): https://forums.macrumors.com/threads/owcs-upcoming-thunderbolt-hub-adds-more-thunderbolt-3-ports-to-your-mac.2270255/page-7
- OSLogStore: https://mjtsai.com/blog/2021/12/10/oslogstore-on-monterey/ · https://developer.apple.com/forums/thread/744806 · https://eclecticlight.co/2024/07/15/writing-a-third-generation-log-browser-using-swiftui-1-getting-log-entries/ · https://stackoverflow.com/questions/79364678/
- `log` requires admin: https://derflounder.wordpress.com/2026/01/17/enabling-a-standard-user-account-to-access-the-unified-system-log-on-macos-using-the-log-command-line-tool/ · `log` options: https://ss64.com/mac/log.html · `ioreg(8)`: https://keith.github.io/xcode-man-pages/ioreg.8.html
- SPUSBDataType removal: https://discussions.apple.com/thread/256180514 · https://stackoverflow.com/questions/79775991/ · https://apple.stackexchange.com/questions/170105/ · usbi: https://gist.github.com/kaushikgopal/7e1555569cd5bb3138cb5ca67bb7a4ae
- SPPowerDataType keys: https://bynkiidotcom.wordpress.com/2025/01/26/grabbing-system_profiler-data-in-powershell/
- pmset log samples: https://apple.stackexchange.com/questions/446849/
- EDID keys on Apple silicon: https://github.com/reportmate/reportmate-client-mac/issues/95
- Overcurrent kernel text (2016): https://discussions.apple.com/thread/7435668
