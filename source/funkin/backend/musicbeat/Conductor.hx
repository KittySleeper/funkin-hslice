package funkin.backend.musicbeat;

import funkin.backend.Song.Chart;

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
			if (songPosition >= change.songTime) {
				lastChange = change;
				changeBPM(lastChange.bpm);
			} else {
				break;
			}
		}

		curStep = lastChange.stepTime + Math.floor((songPosition - lastChange.songTime) / stepCrochet);
		curBeat = Math.floor(curStep / 4);
	}

	public static function mapBPMChanges(song:Chart):Void
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		baseBpm = curBPM;
		changeBPM(baseBpm);

		var bpmEvents:Array<Dynamic> = [];
		for (event in song.events)
		{
			if (event.name == "Change BPM")
				bpmEvents.push(event);
		}

		bpmEvents.sort(function(a:Dynamic, b:Dynamic):Int {
			return Reflect.compare(a.time, b.time);
		});

		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (event in bpmEvents)
		{
			if (event.values == null || event.values.length == 0)
				throw 'Change BPM event at ${event.time} is missing its BPM value.';

			var newBpm:Float = Std.parseFloat(Std.string(event.values[0]));
			if (Math.isNaN(newBpm) || newBpm <= 0)
				throw 'Change BPM event at ${event.time} has an invalid BPM value.';

			if (newBpm == curBPM)
				continue;

			totalSteps += Math.floor((event.time - totalPos) / (60000 / curBPM / 4));
			totalPos = event.time;
			curBPM = newBpm;
			bpmChangeMap.push({
				stepTime: totalSteps,
				songTime: totalPos,
				bpm: curBPM
			});
		}
	}

	public static function changeBPM(newBpm:Float):Void
	{
		bpm = newBpm;
		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}
}
