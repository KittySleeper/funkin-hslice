package funkin.backend.musicbeat;

class Conductor
{
	public static var bpm:Float = 100;
	public static var baseBpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000);
	public static var stepCrochet:Float = crochet / 4;
	public static var songPosition:Float = 0;
	public static var lastSongPos:Float = 0;
	public static var offset:Float = 0;

	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = (safeFrames / 60) * 1000;

	public static var curBeat(default, null):Int = 0;
	public static var curStep(default, null):Int = 0;
	public static var bpmChangeMap:Array<Dynamic> = [];

	public static function update():Void
	{
		if (lastSongPos != songPosition)
			lastSongPos = songPosition;

		var lastChange:Dynamic = {
			stepTime: 0,
			songTime: 0,
			bpm: baseBpm
		};

		for (change in bpmChangeMap)
		{
			if (songPosition >= change.songTime)
				lastChange = change;
			else
				break;
		}

		changeBPM(lastChange.bpm);
		curStep = lastChange.stepTime + Math.floor((songPosition - lastChange.songTime) / stepCrochet);
		curBeat = Math.floor(curStep / 4);
	}

	public static function mapBPMChanges(song:Dynamic):Void
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		baseBpm = curBPM;
		changeBPM(baseBpm);

		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			var section:Dynamic = song.notes[i];
			if (section.changeBPM && section.bpm != curBPM)
			{
				curBPM = section.bpm;
				bpmChangeMap.push({
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM
				});
			}

			var deltaSteps:Int = section.lengthInSteps;
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
	}

	public static function changeBPM(newBpm:Float):Void
	{
		bpm = newBpm;
		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}
}
