package funkin.backend.util;

class CoolUtil {
    private static final _byteUnits:Array<String> = ["b", "kb", "mb", "gb", "tb", "pb"];

    /**
     * Takes an amount of bytes and finds the fitting unit. Makes sure that the
     * value is below 1024. Example: formatBytes(123456789); -> 117.74mb
     */
    public static function formatBytes(bytes:Float, precision:Int = 2):String {
        var curUnit:Int = 0;

        while (bytes >= 1024 && curUnit < _byteUnits.length - 1) {
            bytes /= 1024;
            curUnit++;
        }

        return FlxMath.roundDecimal(bytes, precision) + _byteUnits[curUnit];
    }
}