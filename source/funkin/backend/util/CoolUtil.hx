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

	/**
     * Lerp but not Framerate Dependent
     * Delta should be your Elapsed variable
     *
	 * Returns the linear interpolation of two numbers if `ratio`
	 * is between 0 and 1, and the linear extrapolation otherwise.
	 *
	 * Examples:
	 *
	 * ```haxe
	 * lerp(a, b, 0) = a
	 * lerp(a, b, 1) = b
	 * lerp(5, 15, 0.5) = 10
	 * lerp(5, 15, -1) = -5
	 * ```
	 */
    public static function coolLerp(a:Float, b:Float, ratio:Float, delta:Float): Float {
        return FlxMath.lerp(a, b, Math.pow(ratio, delta * 60));
    }
}