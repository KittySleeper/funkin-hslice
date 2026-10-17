package;

import funkin.states.menus.freeplay.FreeplayState;
import flixel.FlxGame;
import openfl.display.Sprite;
import funkin.ui.DebugOverlay;
import sys.FileSystem;

class Main extends Sprite
{
	public static var game:FlxGame;
	public static var debugOverlay:DebugOverlay;

	public function new()
	{
		super();

		for (content in FileSystem.readDirectory("./content"))
			Paths.ASSETS_PATHS.push("content/" + content);

		game = new FlxGame(0, 0, FreeplayState, 0, 0, true);

		@:privateAccess
		game._customSoundTray = funkin.ui.FunkinSoundTray;
		addChild(game);

		debugOverlay = new DebugOverlay();
		addChild(debugOverlay);

		FlxG.signals.preStateSwitch.add(() ->
		{
			Paths.dumpCache();
		});

		// Stolen From https://git.gay/AnimusTeam/gbPsych/src/commit/7131cbbb41dd5b82cb7587ce2a20d933bf5a8ce8/source/Main.hx#L151
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(openfl.events.UncaughtErrorEvent.UNCAUGHT_ERROR,
			(event:openfl.events.UncaughtErrorEvent) ->
			{
				event.stopImmediatePropagation();
				event.stopPropagation();
				event.preventDefault();
				_onCrash(event.error);
			});

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(_onCrash);
		#end
	}

	override function __enterFrame(delta:Float)
	{
		@:privateAccess {
			FlxG.game.__enterFrame(delta);
			debugOverlay.__enterFrame(delta);
		}

		@:privateAccess
		FlxG.mouse.enabled = !FlxG.game._lostFocus;
	}

	private static var _sourceMap:haxe.ds.StringMap<String> = new haxe.ds.StringMap<String>();

	public static function callstackToString(callstack:Array<haxe.CallStack.StackItem>):String
	{
		var str:String = "";
		var stackIndex:Int = 0;

		for (stackItem in callstack)
		{
			switch (stackItem)
			{
				case FilePos(_, file, line, _):
					str += '$file:$line\n';
					str += '-> ${_getLineFromFile(file, line)}\n\n';
					stackIndex++;

				default:
					str += "#" + stackIndex + " " + Std.string(stackItem) + "\n";
					stackIndex++;
			}
		}
		return str;
	}

	// stole from troll engine 🧌 (and https://git.gay/AnimusTeam/gbPsych/src/commit/7131cbbb41dd5b82cb7587ce2a20d933bf5a8ce8/source/Main.hx#L259)
	// https://github.com/riconuts/FNF-Troll-Engine/blob/d5f66fb1d5ab53a04a8831bac5533268cf5d925b/source/funkin/FNFGame.hx#L183
	private static function _onCrash(err:String):Void
	{
		Sys.print("\nCall stack starts below");

		var callstack:String = Main.callstackToString(haxe.CallStack.exceptionStack(true));
		Sys.print('\n${callstack}${err}\n');

		var boxMessage:String = '${callstack}${err}\n';

		#if SAVE_CRASH_LOGS
		if (!FileSystem.exists('crash'))
			FileSystem.createDirectory('crash');

		final dateNow:String = Date.now().toString().replace(" ", "_").replace(":", "'");
		final fileName:String = 'crash/${FlxG.stage?.application?.meta.get("file")?.replace(" ", "-") ?? "App"}-${dateNow}.txt';

		boxMessage += '\nCall stack was saved as ${fileName}';
		File.saveContent(fileName, callstack);
		#end
		boxMessage += '\nPlease report this to the git repo:\nhttps://github.com/KittySleeper/better-than-vslice\n\n';
		boxMessage += "\nWould you like to go to the main menu?";

		if (FlxG.stage?.window != null)
		{
			final button:Int = FlxG.stage.window.alert(lime.ui.MessageBoxType.ERROR, boxMessage, err, ["Yes", "No", "Cancel"]);
			switch (button)
			{
				case 0: // Yes (retreat to main menu)
					FlxG.switchState(() -> new FreeplayState());
					return;

				case 2: // Cancel (continue in a potentially unstable state)
					return;

				default: // Pass through to the part that closes the game
			}
		}
		#if DISCORD_ALLOWED
		DiscordRPC.shutdown();
		#end
		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.dispose();
		#end
		openfl.system.System.exit(1);
	}

	private static function _getFile(path:String):Null<String>
	{
		return _sourceMap.get(path.replace("\\", "/"));
	}

	private static function _getLineFromFile(path:String, line:Int):String
	{
		var content:String = _getFile(path);
		if (content != null)
		{
			var lines = content.replace("\r", "").split("\n");
			if (line > 0 && line <= lines.length)
				return lines[line - 1].trim();
		}
		return "Could not retrieve source code line.";
	}
}
