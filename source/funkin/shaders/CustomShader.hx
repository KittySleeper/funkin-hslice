package funkin.shaders;

import flixel.addons.display.FlxRuntimeShader;
import funkin.backend.Paths;

using StringTools;

class CustomShader extends FlxRuntimeShader
{
	public function new(key:String)
	{
		if (key.endsWith(".frag"))
			key = key.substr(0, key.length - ".frag".length);

		var fragmentSource = Paths.shader(key);
		if (fragmentSource == null)
			throw 'Shader file not found: assets/shaders/$key.frag';

		super(fragmentSource);
	}

	public function get(name:String):Dynamic
	{
		var parameter:Dynamic = Reflect.field(data, name);
		if (parameter == null)
			throw 'Shader uniform "$name" not found.';

		var values:Array<Dynamic> = cast Reflect.field(parameter, "value");
		if (values == null || values.length == 0)
			throw 'Shader uniform "$name" has no value.';

		return values.length == 1 ? values[0] : values;
	}

	public function set(name:String, value:Dynamic):Dynamic
	{
		var parameter:Dynamic = Reflect.field(data, name);
		if (parameter == null)
			throw 'Shader uniform "$name" not found.';

		var values:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : [value];
		Reflect.setField(parameter, "value", values);
		return value;
	}
}
