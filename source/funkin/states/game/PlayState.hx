package funkin.states.game;

import funkin.backend.HScript;
import funkin.states.menus.freeplay.FreeplayState;
import flixel.FlxObject;
import funkin.states.game.objects.*;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import openfl.desktop.ClipboardFormats;
import openfl.desktop.Clipboard;
import haxe.Json;
import funkin.backend.util.MemoryUtil;

class PlayState extends MusicBeatState
{
	public static var songData:Chart;
	public static var songMeta:SongMetaData;
	public static var curSong:String = "";
	public static var curDifficulty:String = "";
	public static var events:Array<EventData> = [];

	public var tracks:FlxSoundGroup = new FlxSoundGroup();

	public var stage:Stage;

	public var strumLines:FlxTypedSpriteGroup<StrumLine> = new FlxTypedSpriteGroup();
	public var healthBarBG:FlxSprite;
	public var healthBar:FlxBar;

	public var health:Float = 50;

	public var camGame:FlxCamera;
	public var gameDefaultZoom:Float = 0.85;
	public var gameCameraFollow:FlxObject = new FlxObject();
	public var gameCameraFollowShouldLerp:Bool = false;

	public var camHUD:FlxCamera;
	public var hudDefaultZoom:Float = 1;

	public var camZoomingInterval:Int = 4;
	public var camZoomingStrength:Float = 1;

	public var endSong:Void->Void = () ->
	{
		FlxG.switchState(() -> new FreeplayState());
	};

	override public function create()
	{
		events = songData.events.copy();

		Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, Json.stringify(songData, null, "\t"));

		for (track in Paths.readDirectory('songs/$curSong/tracks'))
			tracks.add(FlxG.sound.play(Paths.song('$curSong/tracks/$track')));

		if (tracks.sounds.isEmpty())
			throw 'Song "$curSong" has no audio tracks in assets/songs/$curSong/tracks.';

		FlxG.sound.music = tracks.sounds[0];
		FlxG.sound.music.onComplete = endSong;
		Conductor.mapBPMChanges(songData);

		camGame = new FlxCamera();
		camGame.zoom = gameDefaultZoom;
		camGame.follow(gameCameraFollow, LOCKON, FlxMath.MAX_VALUE_FLOAT);
		FlxG.cameras.reset(camGame);

		camHUD = new FlxCamera();
		camHUD.zoom = hudDefaultZoom;
		camHUD.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camHUD, false);

		stage = new Stage(songData.stage);
		gameDefaultZoom = stage.stageData.zoom;

		for (scriptName in Paths.readDirectory('songs/$curSong/scripts'))
		{
			var scriptType:String = "";

			for (fileType in HScript.supportedFileTypes)
			{
				if (scriptName.endsWith('.$fileType'))
					scriptType = "haxe";
			}

			if (scriptType == "haxe")
				createHScript('songs/$curSong/scripts/$scriptName');
		}

		add(strumLines);

		for (i => strumData in songData.strumLines)
		{
			var strum:StrumLine = new StrumLine(strumData.position[0], strumData.position[1], strumData, i);
			strumLines.add(strum);

			for (charName in strumData.characters)
			{ // maybe make it so that Characters are handled by strumline???
				var charStageData:Stage.StageCharacterData = stage.getCharacterData(strumData.charPosition);
				trace(charStageData);

				var char:Character = new Character(charStageData.position[0], charStageData.position[1], charName, strumData.charPosition == "player");
				char.characterData.cameraOffset[0] += charStageData.cameraOffset[0];
				char.characterData.cameraOffset[1] += charStageData.cameraOffset[1];
				strum.characters.push(char);
				add(char);
			}
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

		stage.addObjects();

		super.create();

		callScriptFunction("createPost");
	}

	override public function destroy()
	{
		callScriptFunction("destroy");

		songData.events = null;
		songData.strumLines = null;
		songData = null;
		events = null;

		super.destroy();

		MemoryUtil.clearAll();
	}

	override public function update(elapsed:Float)
	{
		callScriptFunction("update", [elapsed]);

		if (FlxG.keys.justPressed.ESCAPE)
			endSong();

		for (event in events)
		{
			if (Conductor.songPosition >= event.time)
			{
				events.remove(event);
				eventHit(event);
			}
		}

		for (track in tracks.sounds)
			if (track.playing && (track.time < tracks.sounds[0].time - 5 || track.time > tracks.sounds[0].time + 5))
				track.time = tracks.sounds[0].time;

		camGame.zoom = CoolUtil.coolLerp(gameDefaultZoom, camGame.zoom, 0.95, elapsed);
		camHUD.zoom = CoolUtil.coolLerp(hudDefaultZoom, camHUD.zoom, 0.95, elapsed);

		super.update(elapsed);

		callScriptFunction("updatePost", [elapsed]);
	}

	override function beatHit()
	{
		callScriptFunction("beatHit");

		if (camGame.zoom < 1.35 && curBeat % camZoomingInterval == 0)
		{
			camGame.zoom += 0.015 * camZoomingStrength;
			camHUD.zoom += 0.03 * camZoomingStrength;
		}

		for (strum in strumLines)
			for (char in strum.characters)
				if (!char.isSinging)
					char.dance();

		super.beatHit();

		callScriptFunction("beatHitPost");
	}

	override public function onFocus():Void
	{
		super.onFocus();
		// FlxG.sound.music.play();
	}

	function eventHit(event:EventData)
	{
		switch event.name
		{
			case "Camera Target": // dear god i need too fix this up-
				gameCameraFollow.setPosition(strumLines.members[event.values[0]].characters[0].getMidpoint().x
					+ strumLines.members[event.values[0]].characters[0].characterData.cameraOffset[0],
					strumLines.members[event.values[0]].characters[0].getMidpoint().y
						+ strumLines.members[event.values[0]].characters[0].characterData.cameraOffset[1]);
			case "Camera Beat Interval Change":
				camZoomingStrength = event.values[0];
				camZoomingInterval = event.values[1];
		}

		callScriptFunction("eventHit", [event]);
	}

	public static function loadSong(songName:String, songDifficulty:String = "hard")
	{
		curSong = songName;
		curDifficulty = songDifficulty;
		songData = Song.loadSong(curSong, curDifficulty);
	}
}
