package;

class PlayState extends MusicBeatState
{
	var curDifficulty:String = "hard";
	var curSong:String = "malediction";
	var songData:Dynamic;
	var tracks:FlxSoundGroup = new FlxSoundGroup();
	var notes:FlxTypedGroup<FlxSprite> = new FlxTypedGroup();

	override public function create()
	{
		songData = Paths.json('songs/$curSong/charts/$curDifficulty').song;
		
		for (track in Paths.readDirectory('songs/$curSong/tracks')) {	
			tracks.add(FlxG.sound.play(Paths.song('$curSong/tracks/$track')));
		}

		FlxG.sound.music = tracks.sounds[0];

		Conductor.mapBPMChanges(songData);

		super.create();
	}

	override public function update(elapsed:Float)
	{
		for (track in tracks.sounds) {
			if (track.time < tracks.sounds[0].time - 5 || track.time > tracks.sounds[0].time + 5)
				track.time = tracks.sounds[0].time;
		}

		super.update(elapsed);
	}

	override function beatHit() {
		super.beatHit();
	}
}
