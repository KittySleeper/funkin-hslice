package funkin.backend.musicbeat;

import flixel.FlxState;

class MusicBeatState extends FlxState
{
	public var curBeat(get, never):Int;
	public var curStep(get, never):Int;

	private inline function get_curBeat():Int
	{
		return Conductor.curBeat;
	}

	private inline function get_curStep():Int
	{
		return Conductor.curStep;
	}

	override public function create()
	{
		super.create();
	}

	override public function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		else
			Conductor.songPosition = 0;

		var oldStep:Int = curStep;
		Conductor.update();

		if (oldStep != curStep && curStep >= 0)
			stepHit();

		super.update(elapsed);
	}

	public function stepHit():Void
	{
		if (Conductor.curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
	}
}
