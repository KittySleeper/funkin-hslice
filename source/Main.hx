package;

import flixel.FlxGame;
import openfl.display.Sprite;
import funkin.ui.DebugOverlay;

class Main extends Sprite
{
	public static var game:FlxGame;
	public static var debugOverlay:DebugOverlay;

	public function new()
	{
		super();
		
		game = new FlxGame(0, 0, funkin.states.menus.freeplay.FreeplayState, 0, 0, true);
		
		@:privateAccess
		game._customSoundTray = funkin.ui.FunkinSoundTray;
		addChild(game);

		debugOverlay = new DebugOverlay();
		addChild(debugOverlay);
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
}
