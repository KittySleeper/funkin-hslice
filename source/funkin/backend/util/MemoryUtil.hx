package funkin.backend.util;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif java
import java.vm.Gc;
#elseif neko
import neko.vm.Gc;
#end

import funkin.api.Memory;

class MemoryUtil {
    /**
     * Forces a minor garbage collection to run.
     */
    public static function clearMinor():Void {
        #if (cpp || java || neko)
        Gc.run(false);
        #end
    }

    /**
     * Forces a major garbage collection to run.
     */
    public static function clearMajor():Void {
        #if cpp
        Gc.run(true);
        Gc.compact();
        #elseif hl
        Gc.major();
        #elseif (java || neko)
        Gc.run(true);
        #end
    }

    /**
     * Forces both a major and minor garbage collection to run.
     *
     * ! `[WARNING]` - This can be expensive!
     */
    public static function clearAll():Void {
        clearMajor();
        clearMinor();
    }

    public static function enable():Void {
        #if (cpp || hl)
        Gc.enable(true);
        #end
    }

    public static function disable():Void {
        #if (cpp || hl)
        Gc.enable(false);
        #end
    }

    public static function currentMemUsage():Float {
        #if cpp
        return Gc.memInfo64(Gc.MEM_INFO_USAGE);
        #elseif hl
        return Gc.stats().currentMemory;
        #elseif sys
        return System.totalMemoryNumber;
        #else
        return 0;
        #end
    }

    public static function currentAppMemUsage():Float {
        #if cpp
        return cast Memory.getCurrentUsage();
        #else
        return currentMemUsage();
        #end
    }

    public static function peakMemUsage():Float {
        final mem:Float = currentMemUsage();
        if(mem > _peakGcMem) _peakGcMem = mem;
        return _peakGcMem;
    }

    public static function peakAppMemUsage():Float {
        final mem:Float = currentAppMemUsage();
        if(mem > _peakAppMem) _peakAppMem = mem;
        return _peakAppMem;
    }

    private static var _peakGcMem:Float = 0;
    private static var _peakAppMem:Float = 0;
}