package funkin.backend.musicbeat;

import flixel.FlxState;

/**
	* State That Handles Things For Conductor
	* Conductor Can Not Be Used Outside Of This State Unless You Are Manually Handling It Yourself.
	* TODO: Maybe Make Some Helper Functions In Conductor So You Can Just Do
	* ```haxe
	* var conductor:Conductor = new Conductor();
	* 
	* function update(elapsed:Float) {
	* 	conductor.update();
	* }
	* ```
 */
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
