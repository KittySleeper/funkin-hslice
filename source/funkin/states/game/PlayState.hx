package funkin.states.game;

import funkin.states.game.objects.StrumLine;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import openfl.desktop.ClipboardFormats;
import openfl.desktop.Clipboard;
import haxe.Json;

class PlayState extends MusicBeatState
{
	public static var songData:Chart;
	public static var curSong:String = "malediction";
	public static var curDifficulty:String = "hard";
	public static var events:Array<EventData> = [];

	public var tracks:FlxSoundGroup = new FlxSoundGroup();

	public var strumLines:FlxTypedSpriteGroup<StrumLine> = new FlxTypedSpriteGroup();
	public var healthBarBG:FlxSprite;
	public var healthBar:FlxBar;

	public var health:Float = 50;

	public var camGame:FlxCamera;
	public var gameDefaultZoom:Float = 1.05;

	public var camHUD:FlxCamera;
	public var hudDefaultZoom:Float = 1;

	public var camZoomingInterval:Int = 4;
	public var camZoomingStrength:Float = 1;

	override public function create()
	{
		songData = Song.loadSong(curSong, curDifficulty);
		events = songData.events.copy();

		Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, Json.stringify(songData, null, "\t"));

		for (track in Paths.readDirectory('songs/$curSong/tracks'))
		{
			tracks.add(FlxG.sound.play(Paths.song('$curSong/tracks/$track')));
		}

		FlxG.sound.music = tracks.sounds[0];

		Conductor.mapBPMChanges(songData);

		camGame = new FlxCamera();
		camGame.bgColor = FlxColor.GRAY;
		FlxG.cameras.add(camGame);

		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camHUD, false);

		super.create();

		add(strumLines);

		for (i => strumData in songData.strumLines) {
			var strum:StrumLine = new StrumLine(strumData.position[0], strumData.position[1], strumData, i);
			strumLines.add(strum);
		}

		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.image('game/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		add(healthBarBG);

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 100);
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
		add(healthBar);

		for (obj in [healthBarBG, healthBar, strumLines])
			obj.camera = camHUD;
	}

	override public function update(elapsed:Float)
	{
		for (event in events)
		{
			if (Conductor.songPosition >= event.time)
			{
				events.remove(event);
				eventHit(event.name, event.values);
			}
		}

		for (track in tracks.sounds)
			if (track.playing && (track.time < tracks.sounds[0].time - 5 || track.time > tracks.sounds[0].time + 5))
				track.time = tracks.sounds[0].time;

		FlxG.camera.zoom = CoolUtil.coolLerp(gameDefaultZoom, FlxG.camera.zoom, 0.95, elapsed);
		camHUD.zoom = CoolUtil.coolLerp(hudDefaultZoom, camHUD.zoom, 0.95, elapsed);

		super.update(elapsed);
	}

	override function beatHit()
	{
		super.beatHit();

		if (camGame.zoom < 1.35 && curBeat % camZoomingInterval == 0)
		{
			camGame.zoom += 0.015 * camZoomingStrength;
			camHUD.zoom += 0.03 * camZoomingStrength;
		}
	}

	override public function onFocus():Void
	{
		super.onFocus();
		// FlxG.sound.music.play();
	}

	function eventHit(name:String, values:Array<Dynamic>)
	{
		trace(name);
	}
}
