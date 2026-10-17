package;

/**
    [![](https://thomasdarkson.com/assets/stickers/sticker.png)](https://thomasdarkson.com)

    Main class of HxSysInfo, containing methods for retrieving various system information.

    Methods:
    - `getOS():String`
    - `getOSVersion():String`
    - `getArchitecture():String`
    - `getCPUName():String`
    - `getCPUCoreCount():Int`
    - `getCPUThreadCount():Int`
    - `getTotalRAM():Float`
    - `getAvailableRAM():Float`
    - `getGPUCount():Int`
    - `getGPUName(index:Int):String`
    - `getGPUVRAM(index:Int):Float`
    - `getManufacturer():String`
    - `getModel():String`
    - `getHostname():String`
    - `getUptime():Float`
    - `getDiskCount():Int`
    - `getDiskName(index:Int):String`
    - `getDiskModel(index:Int):String`
    - `getDiskType(index:Int):String`
    - `getDiskSize(index:Int):Float`
    - `getPartitionCount(diskIndex:Int):Int`
    - `getPartitionName(diskIndex:Int, partIndex:Int):String`
    - `getPartitionFileSystem(diskIndex:Int, partIndex:Int):String`
    - `getPartitionSize(diskIndex:Int, partIndex:Int):Float`
    - `getPartitionFreeSpace(diskIndex:Int, partIndex:Int):Float`
    - `getSystemDiskIndex():Int`
    - `getActiveGPUIndex():Int` **(OpenFL ONLY)**

    @see `SysInfo.Converter`
**/
#if !display
@:build(macro.Macro.xml('system'))
#end
@:include("SysInfo.h")
@:keep
extern class SysInfo {
    /**
        The platform name. Can be `Windows`, `Linux`, `macOS`, `iOS` or `Android`.
    **/
    @:native("SysInfo::getOS") public static function getOS():String;

    /**
        The OS version. The format differs per platform.

        Examples:
        - Windows: `10.0.22631`
        - Linux: `Ubuntu 24.04.4 LTS`
        - macOS: `14.8.9`
        - iOS: `17.5`
        - Android: `14`
    **/
    @:native("SysInfo::getOSVersion") public static function getOSVersion():String;

    /**
        The CPU architecture as reported by the OS (e.g. `x86_64`, `ARM64`, `aarch64`).

        On iOS, this is not the CPU architecture. iOS reports the device hardware identifier
        (e.g. `iPhone14,5`) instead.

        On Linux and Android, a 32-bit build reports the real 64-bit host architecture.

        On macOS, an Intel build running under Rosetta 2 (whose support will drop on macOS 28) on
        Apple Silicon correctly reports `arm64`, not the `x86_64` the process sees itself as.
    **/
    @:native("SysInfo::getArchitecture") public static function getArchitecture():String;

    /**
        The CPU's model.
    
        On iOS, so this is the device hardware identifier (e.g. `iPhone14,5`) instead of the CPU's model. 
        
        On Android, it depends on the device. This can fall back to the chip's codename
        (e.g. `lahaina`) rather than a friendly CPU name.
    **/
    @:native("SysInfo::getCPUName") public static function getCPUName():String;

    /**
        Physical CPU core count where the platform can determine it, otherwise the logical (thread) count as a fallback. 
        
        On architectures without SMT/hyperthreading (all iOS and Android devices) this is generally equal to `getCPUThreadCount()`.
    **/
    @:native("SysInfo::getCPUCoreCount") public static function getCPUCoreCount():Int;

    /**
        Logical CPU count. 
        
        Reflects currently **online** logical CPUs. On platforms that can hot-plug cores for power saving (Android),
        this can be lower than the CPU's maximum count.
    **/
    @:native("SysInfo::getCPUThreadCount") public static function getCPUThreadCount():Int;

    /** 
        Total physical RAM in bytes.

        On platforms where a portion of RAM can be reserved for hardware (e.g. Windows),
        this doesn't reflect the actual amount of physical RAM in the system. 
        Instead, it reflects the maximum amount of RAM available to the system.
    **/
    @:native("SysInfo::getTotalRAM") public static function getTotalRAM():Float;

    /**
        An estimate of available RAM in bytes.

        **This does not mean the same thing on every platform.**
        
        On Linux and Android, it refers to memory that is currently free, so it may be lower than the amount of memory that can actually be used. 
        
        On macOS and iOS, it is based on both free and inactive memory, so it may also not represent the exact amount of memory available.
    **/
    @:native("SysInfo::getAvailableRAM") public static function getAvailableRAM():Float;

    /**
        Number of GPUs detected. Always `0` or `1` on mobile platforms (iOS and Android).

        Returns `0` on macOS running on a virtual machine (or a Hackintosh with no hardware accelerated GPU).
    **/
    @:native("SysInfo::getGPUCount") public static function getGPUCount():Int;

    /**
        Name of the GPU at `index`.
        Returns `""` for an invalid range.

        On Linux, some GPUs return the brand and family of the GPU (e.g., `Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9070/9070 XT/9070 GRE]`).

        If the PCI ID database is outdated on the distro, it only returns the brand (e.g., `Advanced Micro Devices, Inc. [AMD/ATI] Device`).

        Run `sudo update-pciids` in the terminal to update your PCI ID database.
    **/
    @:native("SysInfo::getGPUName") public static function getGPUName(index:Int):String;

    /**
        Dedicated VRAM of the GPU at `index` in bytes.

        Always `0` on macOS (unless it has a dedicated GPU), iOS and Android.

        May return `0` if the GPU at `index` is integrated or the correct drivers are not installed or the OS is running in a VM.
    **/
    @:native("SysInfo::getGPUVRAM") public static function getGPUVRAM(index:Int):Float;

    /**
        Device manufacturer (e.g. `LENOVO`, `Dell Inc.`). 

        Always `Apple` on macOS/iOS. 
        
        Can be `""` on Linux, especially in VMs, containers, or ARM boards without SMBIOS.
    **/
    @:native("SysInfo::getManufacturer") public static function getManufacturer():String;

    /**
        Device model.

        On Apple platforms, this is the internal hardware identifier
        (e.g. "MacBookPro18,1", "iPhone14,5").
    **/
    @:native("SysInfo::getModel") public static function getModel():String;

    /**
        The machine's host name.

        On iOS, this always returns a placeholder, like `iPhone`, not the user's real device name.
    **/
    @:native("SysInfo::getHostname") public static function getHostname():String;

    /**
        Seconds since boot (on iOS and macOS, since the current OS session started).
     
        Not guaranteed to stay perfectly accurate across a system
        clock change, so it can drift if the clock is adjusted.
    **/
    @:native("SysInfo::getUptime") public static function getUptime():Float;

    /**
        Number of physical disks detected.
    **/
    @:native("SysInfo::getDiskCount") public static function getDiskCount():Int;

    /**
        OS device name of the disk at `index`.

        Examples: `PhysicalDrive0` (Windows), `/dev/sda` (Linux), `/dev/disk0` (macOS).
        Returns `""` for an invalid index.
    **/
    @:native("SysInfo::getDiskName") public static function getDiskName(index:Int):String;

    /**
        Hardware model of the disk at `index`, when available.
        Returns `""` if the platform cannot provide it.
    **/
    @:native("SysInfo::getDiskModel") public static function getDiskModel(index:Int):String;

    /**
        Type of the disk: `SSD`, `HDD`, `Removable` or `Unknown`.
    **/
    @:native("SysInfo::getDiskType") public static function getDiskType(index:Int):String;

    /**
        Total size of the disk at `index` in bytes.
        Returns `0` for an invalid index.
    **/
    @:native("SysInfo::getDiskSize") public static function getDiskSize(index:Int):Float;

    /**
        Number of partitions detected on the disk at `diskIndex`.
        Returns `0` for an invalid index.
    **/
    @:native("SysInfo::getPartitionCount") public static function getPartitionCount(diskIndex:Int):Int;

    /**
        Name of a partition, usually its mount point, drive letter, or volume name.

        Returns `""` if unavailable.
    **/
    @:native("SysInfo::getPartitionName") public static function getPartitionName(diskIndex:Int, partIndex:Int):String;

    /**
        File system of a partition, such as `NTFS`, `ext4` or `Apple_APFS`, `MS-DOS FAT32`.

        Returns `""` if unavailable.

        On Linux distributions running from a live environment rather than being
        installed on the system, this returns `""` because the partitions are not mounted.
    **/
    @:native("SysInfo::getPartitionFileSystem") public static function getPartitionFileSystem(diskIndex:Int, partIndex:Int):String;

    /**
        Total size of a partition in bytes.
        Returns `0` for an invalid index.
    **/
    @:native("SysInfo::getPartitionSize") public static function getPartitionSize(diskIndex:Int, partIndex:Int):Float;

    /**
        Free space of a mounted partition, in bytes. Returns `0` when it cannot be determined.

        On macOS, an APFS container has no mount point of its own, so this is the free space shared by all
        volumes in the container. It excludes purgeable space, so it may be lower than what Finder shows.
        It is `0` if none of the container's volumes is mounted.
    **/
    @:native("SysInfo::getPartitionFreeSpace") public static function getPartitionFreeSpace(diskIndex:Int, partIndex:Int):Float;

    /**
        Index of the disk the OS is currently running from. Returns `-1` if it cannot be determined.

        Always `-1` on iOS.
    **/
    @:native("SysInfo::getSystemDiskIndex") public static function getSystemDiskIndex():Int;
}

/**
    Helper for converting bytes into other units.

    Usage:

    ```haxe
    var ram:Float = SysInfo.Converter.toGiB(SysInfo.getTotalRAM());
    var disk:Float = SysInfo.Converter.toTiB(SysInfo.getDiskSize(0));
    trace(ram + " GB", disk + " TB");

    trace(SysInfo.Converter.toBit(1.111, 1));  // 8.9, Round the result to one decimal place
    trace(SysInfo.Converter.toBit(1.111, -1)); // 9, Round the result to the nearest whole number (the second argument should be -1 or below)
    trace(SysInfo.Converter.toBit(1.111, 0));  // 8.888, No rounding
    trace(SysInfo.Converter.toBit(1.111));  // 8.888, No rounding again because the second argument defaults to 0
    ```
**/
@:include("Converter.h")
extern class Converter {
    /**
        Converts the number of bytes provided by the methods of this library to bits.

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toBit") public static function toBit(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to kibibytes (kilobytes).
        
        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toKiB") public static function toKiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to mebibytes (megabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toMiB") public static function toMiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to gibibytes (gigabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toGiB") public static function toGiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to tebibytes (terabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toTiB") public static function toTiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to pebibytes (petabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toPiB") public static function toPiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to exbibytes (exabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toEiB") public static function toEiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to zebibytes (zettabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toZiB") public static function toZiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to yobibytes (yottabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toYiB") public static function toYiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to robibytes (ronnabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toRiB") public static function toRiB(bytes:Float, decimal:Int = 0):Float;

    /**
        Converts the number of bytes provided by the methods of this library to quebibytes (quettabytes).

        If `decimal` is greater than `0`, the result is rounded to the specified number of decimal places.

        For example, `SysInfo.Converter.toBit(1.111, 1)` becomes `8.9`, whereas it would normally be `8.888`.
        
        If `decimal` is `-1` or below, the result is rounded to the nearest whole number.
    **/
    @:native("Converter::toQiB") public static function toQiB(bytes:Float, decimal:Int = 0):Float;
}

#if (lime && openfl)
/**
    Helper class exclusive to OpenFL (and Lime).

    As of 1.0.0, the only method is:
    - `getActiveGPUIndex():Int`
**/
class OpenFLSysInfo {
    /**      
        Returns the index of the GPU currently rendering this OpenFL application.

        Behavior may differ between platforms, so this is not guaranteed to return a valid index.
        Returns `-1` if the GPU index cannot be determined.
    **/
    public static function getActiveGPUIndex():Int {
        var c = SysInfo.getGPUCount();
        if (c == 1)
            return 0;
        if (c < 1)
            return -1;

        var gpu = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.RENDERER);
        for (i in 0...c) {
            if (SysInfo.getGPUName(i) == gpu)
                return i;
        }
        return -1;
    }
}
#end