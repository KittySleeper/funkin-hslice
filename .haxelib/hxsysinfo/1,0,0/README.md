[![](https://thomasdarkson.com/assets/stickers/sticker.png)](https://thomasdarkson.com)

[<img src="https://thomasdarkson.com/icons/hxsysinfo.png" style="width:40%; height:auto;">](https://thomasdarkson.com)

# HxSysInfo
> [!NOTE]
> Works on C++ only (hxcpp).

**HxSysInfo** is a Haxe library that can retrieve all kinds of information about the user's system. Only Windows, macOS, Linux, Android and iOS are supported.

------------

| Platform | Compiles? | Tested? |
| -------- | -------   | ----------------------------------------------------- |
| Windows  |    ✅    |    ✅ (Windows 11 23H2 x64, Windows 8.1 x86)          |
| macOS    |    ✅    |    ✅ (macOS Sonoma **VMware Workstation Pro**)       |
| Linux    |    ✅    |    ✅ (Lubuntu 24.04 LTS **VMware Workstation Pro**)  |
| iOS      |    ✅    |    ❌                                                 |
| Android  |    ✅    |    ❌                                                 |
| Other    |    ❓    |    ❌                                                 |

## Installation
`haxelib install HxSysInfo`

Enter this command in the command prompt to get the latest release from the Haxe library.

After installing HxSysInfo, don't forget to add it to your Haxe project.

### OpenFL projects
Add this to `Project.xml` to add HxSysInfo to your OpenFL project:
```xml
<haxelib name="HxSysInfo"/>
```
### Haxe Projects
Add this to `build.hxml` to add HxSysInfo to your Haxe build.
```hxml
-lib HxSysInfo
```

## Usage
```haxe
package;

import SysInfo;
import SysInfo.Converter;
#if (openfl && lime)
import SysInfo.OpenFLSysInfo;
#end

class Main {
    static public function main() {
        Sys.println('OS: ${SysInfo.getOS()}');
        Sys.println('Version: ${SysInfo.getOSVersion()}');
        Sys.println('Architecture: ${SysInfo.getArchitecture()}');
        Sys.println("-----------------------------------------------------------");
        Sys.println('CPU: ${SysInfo.getCPUName()}');
        Sys.println('CPU cores (physical): ${SysInfo.getCPUCoreCount()}');
        Sys.println('CPU threads (logical): ${SysInfo.getCPUThreadCount()}');
        Sys.println("-----------------------------------------------------------");
        var totalRam = SysInfo.getTotalRAM();
        var availableRam = SysInfo.getAvailableRAM();
        Sys.println('Total RAM: ${totalRam} bytes (${Converter.toGiB(totalRam)} gigabytes)');
        Sys.println('Available RAM: ${availableRam} bytes (${Converter.toGiB(availableRam)} gigabytes)');
        Sys.println("-----------------------------------------------------------");
        var gpuCount = SysInfo.getGPUCount();
        Sys.println('GPU count: $gpuCount');
        for (i in 0...gpuCount) {
            var vram = SysInfo.getGPUVRAM(i);
            Sys.println('GPU $i name: ${SysInfo.getGPUName(i)}');
            Sys.println('GPU $i VRAM: ${vram} bytes (${Converter.toGiB(vram)} gigabytes)');
        }
        Sys.println("-----------------------------------------------------------");
        Sys.println('Manufacturer: ${SysInfo.getManufacturer()}');
        Sys.println('Model: ${SysInfo.getModel()}');
        Sys.println('Hostname: ${SysInfo.getHostname()}');
        Sys.println("-----------------------------------------------------------");
        Sys.println('Uptime: ${SysInfo.getUptime()} seconds');
        Sys.println("-----------------------------------------------------------");
        var diskCount = SysInfo.getDiskCount();
        Sys.println('Disk count: $diskCount');
        Sys.println('System disk index: ${SysInfo.getSystemDiskIndex()}');
        Sys.println("-----------------------------------------------------------");
        for (i in 0...diskCount) {
            Sys.println('Disk $i name: ${SysInfo.getDiskName(i)}');
            Sys.println('Disk $i model: ${SysInfo.getDiskModel(i)}');
            Sys.println('Disk $i type: ${SysInfo.getDiskType(i)}');
            var size = SysInfo.getDiskSize(i);
            Sys.println('Disk $i size: ${size} bytes (${Converter.toTiB(size)} terabytes)');
            var partCount = SysInfo.getPartitionCount(i);
            Sys.println('Disk $i partition count: $partCount');
            for (j in 0...partCount) {
                Sys.println('Disk $i partition $j name: ${SysInfo.getPartitionName(i, j)}');
                Sys.println('Disk $i partition $j file system: ${SysInfo.getPartitionFileSystem(i, j)}');
                var psize = SysInfo.getPartitionSize(i, j);
                var freesize = SysInfo.getPartitionFreeSpace(i, j);
                Sys.println('Disk $i partition $j size: ${SysInfo.getPartitionSize(i, j)} bytes (${Converter.toGiB(psize)} gigabytes)');
                Sys.println('Disk $i partition $j free space: ${SysInfo.getPartitionFreeSpace(i, j)} bytes (${Converter.toMiB(freesize)} megabytes)');
            }
            Sys.println("-----------------------------------------------------------");
        }

        #if (openfl && lime)
        var i = OpenFLSysInfo.getActiveGPUIndex();
		trace(SysInfo.getGPUName(i), SysInfo.getGPUVRAM(i));
        #end
    }
}
```

<details> 
    <summary>Example Real Output (Click to expand)</summary>
    
    OS: Windows
    Version: 10.0.22631
    Architecture: x86_64
    -----------------------------------------------------------
    CPU: AMD Ryzen 7 9800X3D 8-Core Processor
    CPU cores (physical): 8
    CPU threads (logical): 16
    -----------------------------------------------------------
    Total RAM: 33627140096 bytes (31.3177146911621 gigabytes)
    Available RAM: 20027822080 bytes (18.6523628234863 gigabytes)
    -----------------------------------------------------------
    GPU count: 1
    GPU 0 name: AMD Radeon RX 9070 XT
    GPU 0 VRAM: 16974905344 bytes (15.8091125488281 gigabytes)
    -----------------------------------------------------------
    Manufacturer: Micro-Star International Co., Ltd.
    Model: MS-7E86
    Hostname: DESKTOP-IS2F7I4
    -----------------------------------------------------------
    Uptime: 158740.468 seconds
    -----------------------------------------------------------
    Disk count: 2
    System disk index: 1
    -----------------------------------------------------------
    Disk 0 name: PhysicalDrive0
    Disk 0 model: HI-LEVEL Elite Series 256GB
    Disk 0 type: SSD
    Disk 0 size: 256060514304 bytes (0.232885681092739 terabytes)
    Disk 0 partition count: 1
    Disk 0 partition 0 name: D:\
    Disk 0 partition 0 file system: NTFS
    Disk 0 partition 0 size: 256043384832 bytes (238.458984375 gigabytes)
    Disk 0 partition 0 free space: 19974209536 bytes (19048.890625 megabytes)
    -----------------------------------------------------------
    Disk 1 name: PhysicalDrive1
    Disk 1 model: Samsung SSD 980 PRO with Heatsink 1TB
    Disk 1 type: SSD
    Disk 1 size: 1000204886016 bytes (0.909681044518948 terabytes)
    Disk 1 partition count: 4
    Disk 1 partition 0 name: PhysicalDrive1 Partition1
    Disk 1 partition 0 file system:
    Disk 1 partition 0 size: 104857600 bytes (0.09765625 gigabytes)
    Disk 1 partition 0 free space: 0 bytes (0 megabytes)
    Disk 1 partition 1 name: PhysicalDrive1 Partition2
    Disk 1 partition 1 file system:
    Disk 1 partition 1 size: 16777216 bytes (0.015625 gigabytes)
    Disk 1 partition 1 free space: 0 bytes (0 megabytes)
    Disk 1 partition 2 name: C:\
    Disk 1 partition 2 file system: NTFS
    Disk 1 partition 2 size: 998977306624 bytes (930.3701171875 gigabytes)
    Disk 1 partition 2 free space: 232620843008 bytes (221844.5234375 megabytes)
    Disk 1 partition 3 name: PhysicalDrive1 Partition4
    Disk 1 partition 3 file system:
    Disk 1 partition 3 size: 1103101952 bytes (1.02734375 gigabytes)
    Disk 1 partition 3 free space: 0 bytes (0 megabytes)
    -----------------------------------------------------------
</details>

## Methods

### Operating System

#### `getOS():String`

The platform name. Can be `Windows`, `Linux`, `macOS`, `iOS` or `Android`.

#### `getOSVersion():String`

The OS version. The format differs per platform.

#### `getArchitecture():String`

The CPU architecture as reported by the OS (e.g. `x86_64`, `ARM64`, `aarch64`).

On iOS, this is not the CPU architecture. iOS reports the device hardware identifier instead.

On Linux and Android, a 32-bit build reports the real 64-bit host architecture.

On macOS, an Intel build running under Rosetta 2 on Apple Silicon correctly reports `arm64`, not the `x86_64` the process sees itself as.

---

### CPU

#### `getCPUName():String`

The CPU's model.

On iOS, this is the device hardware identifier instead of the CPU's model.

On Android, it depends on the device and can fall back to the chip's codename (e.g. `lahaina`) rather than a friendly CPU name.

#### `getCPUCoreCount():Int`

The physical CPU core count where the platform can determine it. Otherwise, the logical (thread) count is used as a fallback.

On architectures without SMT/hyperthreading (all iOS and Android devices), this is generally equal to `getCPUThreadCount()`.

#### `getCPUThreadCount():Int`

The logical CPU count. Reflects currently **online** logical CPUs.

On platforms that can hot-plug cores for power saving (Android), this can be lower than the CPU's maximum count.

---

### Memory

#### `getTotalRAM():Float`

Total physical RAM in bytes.

On platforms where a portion of RAM can be reserved for hardware (e.g. Windows), this doesn't reflect the actual amount of physical RAM in the system. Instead, it reflects the maximum amount of RAM available to the system.

#### `getAvailableRAM():Float`

An estimate of available RAM in bytes.

This does not mean the same thing on every platform. On Linux and Android, it refers to memory that is currently free, so it may be lower than the amount of memory that can actually be used.

On macOS and iOS, it is based on both free and inactive memory, so it may also not represent the exact amount of memory available.

---

### GPU

#### `getGPUCount():Int`

Number of GPUs detected.

Always `0` or `1` on mobile platforms (iOS and Android).

Returns `0` on macOS running on a virtual machine (or a Hackintosh with no hardware-accelerated GPU).

#### `getGPUName(index:Int):String`

Name of the GPU at `index`.
Returns `""` for an invalid range.

On Linux, some GPUs return the brand and family of the GPU (e.g., `Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9070/9070 XT/9070 GRE]`).

If the PCI ID database is outdated on the distro, it only returns the brand (e.g., `Advanced Micro Devices, Inc. [AMD/ATI] Device`).

Run `sudo update-pciids` in the terminal to update your PCI ID database.

#### `getGPUVRAM(index:Int):Float`

Dedicated VRAM of the GPU at `index`, in bytes.

Always `0` on macOS without a dedicated GPU, iOS and Android.

May return `0` if the GPU at `index` is integrated, the correct drivers are not installed, or the OS is running in a virtual machine.

#### `SysInfo.OpenFLSysInfo.getActiveGPUIndex():Int`

> [!WARNING]
> OpenFL and Lime only. Available in `SysInfo.OpenFLSysInfo` class.

Returns the index of the GPU currently rendering this OpenFL application.

Behavior may differ between platforms, so this is not guaranteed to return a valid index.

Returns `-1` if the GPU index cannot be determined.

---

### Device

#### `getManufacturer():String`

Device manufacturer (e.g. `LENOVO`, `Dell Inc.`).

Always `Apple` on macOS/iOS.

Can be `""` on Linux, especially in VMs, containers, or ARM boards without SMBIOS.

#### `getModel():String`

Device model.

On Apple platforms, this is the internal hardware identifier (e.g. `MacBookPro18,1`, `iPhone14,5`).

#### `getHostname():String`

The machine's hostname.

On iOS, this always returns a placeholder, such as `iPhone`, rather than the user's real device name.

#### `getUptime():Float`

Seconds since boot.

On iOS and macOS, this is the time since the current OS session started.

It is not guaranteed to remain perfectly accurate across a system clock change, so it can drift if the clock is adjusted.

---

### Disks

#### `getDiskCount():Int`

Number of physical disks detected.

#### `getDiskName(index:Int):String`

OS device name of the disk at `index`.

Examples:

* `PhysicalDrive0` (Windows)
* `/dev/sda` (Linux)
* `/dev/disk0` (macOS)

Returns `""` for an invalid index.

#### `getDiskModel(index:Int):String`

Hardware model of the disk at `index`, when available.

Returns `""` if the platform cannot provide it.

#### `getDiskType(index:Int):String`

Type of the disk.

Can be `SSD`, `HDD`, `Removable` or `Unknown`.

#### `getDiskSize(index:Int):Float`

Total size of the disk at `index`, in bytes.

Returns `0` for an invalid index.

#### `getSystemDiskIndex():Int`

Index of the disk the OS is currently running from.

Returns `-1` if it cannot be determined.

Always returns `-1` on iOS.

---

### Partitions

#### `getPartitionCount(diskIndex:Int):Int`

Number of partitions detected on the disk at `diskIndex`.

Returns `0` for an invalid index.

#### `getPartitionName(diskIndex:Int, partIndex:Int):String`

Name of a partition, usually its mount point, drive letter, or volume name.

Returns `""` if unavailable.

#### `getPartitionFileSystem(diskIndex:Int, partIndex:Int):String`

File system of a partition, such as `NTFS`, `ext4` or `APFS`.

Returns `""` if unavailable.

On Linux distributions running from a live environment rather than being
installed on the system, this returns `""` because the partitions are not mounted.

#### `getPartitionSize(diskIndex:Int, partIndex:Int):Float`

Total size of a partition, in bytes.

Returns `0` for an invalid index.

#### `getPartitionFreeSpace(diskIndex:Int, partIndex:Int):Float`

Free space of a mounted partition, in bytes.

Returns `0` when it cannot be determined.

On macOS, an APFS container has no mount point of its own, so this is the free space shared by all volumes in the container.

It excludes purgeable space, so it may be lower than what Finder shows.

Returns `0` if none of the container's volumes is mounted.

---

### Unit Conversion

`SysInfo` always returns bytes for memory and storage. `SysInfo.Converter` provides helper methods for converting byte values returned by the library into other units.

All methods accept an optional `decimal` parameter:

* If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.
* If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
* If `decimal` is `0`, the result is not rounded.

#### `toBit(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to bits.

#### `toKiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to kibibytes (kilobytes).

#### `toMiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to mebibytes (megabytes).

#### `toGiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to gibibytes (gigabytes).

#### `toTiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to tebibytes (terabytes).

#### `toPiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to pebibytes (petabytes).

#### `toEiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to exbibytes (exabytes).

#### `toZiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to zebibytes (zettabytes).

#### `toYiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to yobibytes (yottabytes).

#### `toRiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to robibytes (ronnabytes).

#### `toQiB(bytes:Float, decimal:Int = 0):Float`

Converts the specified number of bytes to quebibytes (quettabytes).