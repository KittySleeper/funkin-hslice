package funkin.backend;

import animate.FlxAnimateFrames;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.media.Sound;
import openfl.display.BitmapData;
import sys.io.File;
import sys.FileSystem;

class Paths
{
	public static var epicCacheFromOhio:Map<String, Dynamic> = [];

	inline public static var SOUND_EXT:String = #if web "mp3" #else "ogg" #end;
	public static var ASSETS_PATHS:Array<String> = ["assets"];

	inline static public function sound(key:String):Sound
	{
		if (key.endsWith("." + SOUND_EXT))
			key.replace("." + SOUND_EXT, "");

		if (epicCacheFromOhio.exists('sounds/$key.$SOUND_EXT'))
		{
			return epicCacheFromOhio.get('sounds/$key.$SOUND_EXT');
		}
		else
		{
			var epicSound:Sound = Sound.fromFile(rawFile('sounds/$key.$SOUND_EXT'));
			epicCacheFromOhio.set('sounds/$key.$SOUND_EXT', epicSound);
			return epicSound;
		}
	}

	inline static public function soundRandom(key:String, min:Int, max:Int):Sound
		return sound('$key${FlxG.random.int(min, max)}');

	inline static public function music(key:String)
	{
		if (epicCacheFromOhio.exists('music/$key.$SOUND_EXT'))
		{
			return epicCacheFromOhio.get('music/$key.$SOUND_EXT');
		}
		else
		{
			var epicMusic:Sound = Sound.fromFile(rawFile('music/$key.$SOUND_EXT'));
			epicCacheFromOhio.set('music/$key.$SOUND_EXT', epicMusic);
			return epicMusic;
		}
	}

	inline static public function song(key:String)
	{
        key = FlxStringUtil.remove(key, '.$SOUND_EXT');

		if (epicCacheFromOhio.exists('songs/$key.$SOUND_EXT'))
		{
			return epicCacheFromOhio.get('songs/$key.$SOUND_EXT');
		}
		else
		{
			var epicMusic:Sound = Sound.fromFile(rawFile('songs/$key.$SOUND_EXT'));
			epicCacheFromOhio.set('songs/$key.$SOUND_EXT', epicMusic);
			return epicMusic;
		}
	}

	inline static public function image(key:String, folder:String = "images"):FlxGraphic
	{
		if (epicCacheFromOhio.exists('$folder/$key.png'))
		{
			return FlxGraphic.fromGraphic(epicCacheFromOhio.get('$folder/$key.png'));
		}
		else
		{
			var bitmap = BitmapData.fromFile(rawFile('$folder/$key.png'));
			var epicImage:FlxGraphic = FlxGraphic.fromBitmapData(bitmap);
			epicCacheFromOhio.set('$folder/$key.png', epicImage);
			epicImage.persist = true;
			return epicImage;
		}
	}

	inline static public function getSparrowAtlas(key:String, folder:String = "images"):FlxAtlasFrames
		return FlxAtlasFrames.fromSparrow(image(key, folder), xml('$folder/$key'));

	inline static public function getAnimateAtlas(key:String, folder:String = "images"):FlxAnimateFrames
	{
		if (epicCacheFromOhio.exists('images/$key'))
		{
			return epicCacheFromOhio.get('images/$key');
		}
		else
		{
			var frames:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(rawFile('$folder/$key'));
			frames.parent.persist = true;
			epicCacheFromOhio.set('$folder/$key', frames);
			return frames;
		}
	}

	inline static public function getPackerAtlas(key:String, folder = "images")
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, folder), txt('$folder/$key'));

	inline static public function xml(key:String)
		return fileData('$key.xml');

	inline static public function txt(key:String)
		return fileData('$key.txt');

	inline static public function shader(key:String)
		return fileData('shaders/$key.frag');

	inline static public function json(key:String):Dynamic
		return exists('$key.json') ? Json.parse(fileData('$key.json')) : Json.parse("{}");

	inline static public function lua(key:String)
		return fileData('$key.lua');

	inline static public function font(key:String, type:String = "ttf")
		return rawFile('fonts/$key.$type');

	inline static public function fileData(key:String)
		return Paths.exists(key) ? File.getContent(rawFile(key)) : null;

	static public function exists(key:String):Bool
	{
		#if sys
		for (path in ASSETS_PATHS)
		{
			if (FileSystem.exists('$path/$key'))
				return true;
		}
		return false;
		#else
		return true;
		#end
	}

	static public function rawFile(key:String):String
	{
		for (path in ASSETS_PATHS)
		{
			#if sys
			if (FileSystem.exists('$path/$key'))
				return '$path/$key';
			#end
		}

		return 'assets/$key';
	}

	static public function readDirectory(key:String):Array<String>
	{
		var dirList:Array<String> = [];

		#if sys
		for (path in ASSETS_PATHS)
		{
			if (FileSystem.exists('$path/$key'))
				for (dir in FileSystem.readDirectory('$path/$key'))
					dirList.push(dir);
		}
		#end

		return dirList;
	}

	inline static public function dumpCache():Void
	{
		for (key => value in epicCacheFromOhio)
		{
			if (Std.isOfType(value, FlxGraphic))
				cast(value, FlxGraphic).destroy();

			if (Std.isOfType(value, FlxAtlasFrames))
				cast(value, FlxAtlasFrames).destroy();

			if (Std.isOfType(value, FlxAnimateFrames))
				cast(value, FlxAnimateFrames).destroy();
		}

		epicCacheFromOhio.clear();

		#if cpp
		cpp.vm.Gc.run(true);
		#end
	}
}
