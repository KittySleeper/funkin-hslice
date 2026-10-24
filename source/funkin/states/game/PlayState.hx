package funkin.states.game;

import funkin.backend.HScript;
import funkin.states.menus.freeplay.FreeplayState;
import flixel.FlxObject;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxEase.EaseFunction;
import funkin.states.game.objects.StrumLine.RatingData;
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

	public var dad(get, never):Character;

	private function get_dad():Character
		return strumLines.members[0].characters[0];

	public var boyfriend(get, never):Character;

	private function get_boyfriend():Character
		return strumLines.members[1].characters[0];

	public var ratingGroup:FlxTypedSpriteGroup<FlxSprite> = new FlxTypedSpriteGroup();

	public var strumLines:FlxTypedSpriteGroup<StrumLine> = new FlxTypedSpriteGroup();
	public var healthBarBG:FlxSprite;
	public var healthBar:FlxBar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	public var score:Int = 0;
	public var combo:Int = 0;
	public var misses:Int = 0;
	public var totalJudgedNotes:Int = 0;
	public var totalAccuracyWeight:Float = 0;
	public var accuracy:Float = 100;
	public var scoreTxt:FlxText;

	public var health:Float = 50;

	public var camGame:FlxCamera;
	public var gameDefaultZoom:Float = 0.85;
	public var gameCameraFollow:FlxObject = new FlxObject();
	public var gameCameraFollowShouldLerp:Bool = false;
	var cameraMoveTween:FlxTween;
	var cameraZoomTween:FlxTween;
	var cameraHudZoomTween:FlxTween;

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
			#if cpp
			else if (scriptName.endsWith(".lua"))
				createLuaScript('songs/$curSong/scripts/$scriptName');
			#end
		}

		add(ratingGroup);
		add(strumLines);

		for (i => strumData in songData.strumLines)
		{
			var strum:StrumLine = new StrumLine(strumData.position[0], strumData.position[1], strumData, i);
			if (strum.isPlayerLine)
				strum.onJudgement = onPlayerJudgement;
			strumLines.add(strum);

			for (charName in strumData.characters)
			{ // maybe make it so that Characters are handled by strumline???
				var charStageData:Stage.StageCharacterData = stage.getCharacterData(strumData.charPosition);

				var char:Character = new Character(charStageData.position[0], charStageData.position[1], charName, strumData.charPosition == "player");
				char.characterData.cameraOffset[0] += charStageData.cameraOffset[0];
				char.characterData.cameraOffset[1] += charStageData.cameraOffset[1];
				strum.characters.push(char);
				if (charStageData.zIndex != null)
					insert(charStageData.zIndex, char);
				else
					insert(stage.stageData.objects[stage.stageData.objects.length - 1].zIndex, char);
			}
		}

		stage.addObjects();

		healthBarBG = new FlxSprite(0, FlxG.height * 0.9).loadGraphic(Paths.image('game/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();

		healthBar = new FlxBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8), this,
			'health', 0, 100);
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(FlxColor.fromString(dad.characterData.healthColor), FlxColor.fromString(boyfriend.characterData.healthColor));
		add(healthBar);

		add(healthBarBG);

		iconP1 = new HealthIcon(0, 0, boyfriend.characterName, true);
		iconP1.updateHitbox();
		add(iconP1);

		iconP2 = new HealthIcon(0, 0, dad.characterName);
		iconP2.updateHitbox();
		add(iconP2);

		scoreTxt = new FlxText(0, healthBarBG.y + 35, FlxG.width, "");
		scoreTxt.setFormat(Paths.font("vcr"), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		updateScoreTxt();
		add(scoreTxt);

		for (obj in [ratingGroup, healthBarBG, healthBar, iconP1, iconP2, scoreTxt, strumLines])
			obj.camera = camHUD;

		super.create();

		callScriptFunction("createPost");
	}

	override public function destroy()
	{
		if (cameraMoveTween != null)
			cameraMoveTween.cancel();
		if (cameraZoomTween != null)
			cameraZoomTween.cancel();
		if (cameraHudZoomTween != null)
			cameraHudZoomTween.cancel();

		super.destroy();

		songData.events = null;
		songData.strumLines = null;
		songData = null;
		events = null;

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

		if (cameraZoomTween == null)
			camGame.zoom = CoolUtil.coolLerp(gameDefaultZoom, camGame.zoom, 0.95, elapsed);
		if (cameraHudZoomTween == null)
			camHUD.zoom = CoolUtil.coolLerp(hudDefaultZoom, camHUD.zoom, 0.95, elapsed);

		iconP1.health = healthBar.percent;
		iconP2.health = healthBar.percent;
		positionHealthIcons();

		super.update(elapsed);

		callScriptFunction("updatePost", [elapsed]);
	}

	function positionHealthIcons():Void
	{
		var healthPoint:Float = healthBar.x + healthBar.width * (1 - FlxMath.bound(healthBar.percent / 100, 0, 1));
		var iconOverlap:Float = 25;

		iconP2.setPosition(healthPoint - iconP2.width + iconOverlap, healthBar.y + (healthBar.height - iconP2.frameHeight) * 0.5);
		iconP1.setPosition(healthPoint - iconOverlap, healthBar.y + (healthBar.height - iconP1.frameHeight) * 0.5);
	}

	function onPlayerJudgement(rating:RatingData, scorePoints:Int = 0):Void
	{
		if (rating == null)
		{
			score += scorePoints;
			updateScoreTxt();
			return;
		}

		totalJudgedNotes++;
		totalAccuracyWeight += rating.accuracyWeight;

		if (rating.name == "miss")
		{
			combo = 0;
			misses++;
		}
		else
		{
			combo++;
			score += rating.score;
		}
		health = FlxMath.bound(health + rating.health, 0, 100);

		accuracy = totalAccuracyWeight / totalJudgedNotes * 100;
		updateScoreTxt();
		showRating(rating);
	}

	function updateScoreTxt():Void
	{
		scoreTxt.text = 'Score: ${FlxStringUtil.formatMoney(score, false)} • Misses: ${FlxStringUtil.formatMoney(misses, false)} • Accuracy: ${FlxMath.roundDecimal(accuracy, 2)}%';
	}

	function showRating(rating:RatingData):Void
	{
		if (rating.name == "miss" || rating.sprite == "")
			return;

		if (!ratingGroup.members.isEmpty())
			for (rating in ratingGroup.members)
				rating.kill();

		ratingGroup.clear();

		var ratingSprite:FlxSprite = new FlxSprite();
		ratingSprite.loadGraphic(Paths.image('game/ratings/${rating.sprite}'));
		ratingSprite.setGraphicSize(Std.int(ratingSprite.width * 0.7));
		ratingSprite.updateHitbox();
		ratingSprite.screenCenter(X);
		ratingSprite.y = FlxG.height * 0.4;
		showPopup(ratingSprite);
		showCombo(combo, ratingSprite.y + ratingSprite.height);
	}

	function showCombo(comboCount:Int, y:Float):Void
	{
		var digitY:Float = y;

		if (comboCount >= 10)
		{
			var comboSprite:FlxSprite = new FlxSprite();
			comboSprite.loadGraphic(Paths.image("game/ratings/combo"));
			comboSprite.setGraphicSize(Std.int(comboSprite.width * 0.62));
			comboSprite.updateHitbox();
			comboSprite.screenCenter(X);
			comboSprite.y = y;
			showPopup(comboSprite);
			digitY += comboSprite.height + 5;
		}

		var comboString:String = Std.string(comboCount);
		while (comboString.length < 3)
			comboString = '0$comboString';

		var digits:Array<FlxSprite> = [];
		var totalWidth:Float = 0;
		for (digit in comboString.split(""))
		{
			var digitSprite:FlxSprite = new FlxSprite();
			digitSprite.loadGraphic(Paths.image('game/ratings/num$digit'));
			digitSprite.setGraphicSize(Std.int(digitSprite.width * 0.65));
			digitSprite.updateHitbox();
			digits.push(digitSprite);
			totalWidth += digitSprite.width;
		}

		var spacing:Float = 1.65;
		totalWidth += spacing * (digits.length - 1);
		var digitX:Float = (FlxG.width - totalWidth) * 0.5;
		for (digitSprite in digits)
		{
			digitSprite.x = digitX;
			digitSprite.y = digitY;
			digitX += digitSprite.width + spacing;
			showPopup(digitSprite);
		}
	}

	function showPopup(popup:FlxSprite):Void
	{
		popup.velocity.y = -140;
		popup.acceleration.y = 550;
		ratingGroup.add(popup);
		FlxTween.tween(popup, {alpha: 0}, 0.2, {
			startDelay: 0.2,
			onComplete: function(_)
			{
				popup.kill();
			}
		});
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

		iconP1.bop();
		iconP2.bop();

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
		switch (event.name)
		{
			case "Camera Target":
				var targetIndex:Int = Std.int(event.values[0]);
				var ease:String = event.values.length > 1 && event.values[1] != null ? Std.string(event.values[1]) : "CLASSIC";
				var easeDir:String = "InOut";
				var duration:Float = 4;
				var offsetX:Float = 0;
				var offsetY:Float = 0;

				if (event.values.length > 2)
				{
					if (Std.isOfType(event.values[2], String))
					{
						easeDir = Std.string(event.values[2]);
						if (event.values.length > 3 && event.values[3] != null)
							duration = event.values[3];
						if (event.values.length > 4 && event.values[4] != null)
							offsetX = event.values[4];
						if (event.values.length > 5 && event.values[5] != null)
							offsetY = event.values[5];
					}
					else
					{
						if (event.values[2] != null)
							duration = event.values[2];
						if (event.values.length > 3 && event.values[3] != null)
							offsetX = event.values[3];
						if (event.values.length > 4 && event.values[4] != null)
							offsetY = event.values[4];
					}
				}


				var targetCharacter = strumLines.members[targetIndex].characters[0];
				var midpoint = targetCharacter.getMidpoint();
				var targetX = midpoint.x + targetCharacter.characterData.cameraOffset[0] + offsetX;
				var targetY = midpoint.y + targetCharacter.characterData.cameraOffset[1] + offsetY;

				if (cameraMoveTween != null)
					cameraMoveTween.cancel();
				cameraMoveTween = null;

				var shouldTween = event.values.length <= 6 || event.values[6] != false;
				if (!shouldTween || ease.toUpperCase() == "INSTANT" || duration <= 0)
				{
					camGame.followLerp = FlxMath.MAX_VALUE_FLOAT;
					gameCameraFollow.setPosition(targetX, targetY);
				}
				else if (ease.toUpperCase() == "CLASSIC")
				{
					camGame.followLerp = 0.12;
					gameCameraFollow.setPosition(targetX, targetY);
				}
				else
				{
					var movementEase = getCameraEase(ease, easeDir);
					camGame.followLerp = FlxMath.MAX_VALUE_FLOAT;
					cameraMoveTween = FlxTween.tween(gameCameraFollow, {x: targetX, y: targetY},
						duration * Conductor.stepCrochet / 1000, {
							ease: movementEase,
							onComplete: function(_) cameraMoveTween = null
						});
				}
			case "Camera Zoom":
				var targetZoom:Float = event.values[0];
				var duration:Float = event.values.length > 1 && event.values[1] != null ? event.values[1] : 4;
				var ease:String = event.values.length > 2 && event.values[2] != null ? Std.string(event.values[2]) : "linear";
				var easeDir:String = event.values.length > 3 && event.values[3] != null ? Std.string(event.values[3]) : "InOut";
				var mode:String = event.values.length > 4 && event.values[4] != null ? Std.string(event.values[4]) : "direct";
				var shouldTween:Bool = event.values.length <= 5 || event.values[5] != false;
				var cameraName:String = event.values.length > 6 && event.values[6] != null ? Std.string(event.values[6]) : "camGame";
				var multiplicative:Bool = event.values.length > 7 && event.values[7] == true;
				var camera = cameraName == "camHUD" ? camHUD : camGame;

				targetZoom *= switch (mode.toLowerCase())
				{
					case "stage": stage.stageData.zoom;
					case "direct": 1;
					default: throw 'Camera Zoom event has unsupported mode "$mode".';
				}
				if (multiplicative)
					targetZoom *= camera.zoom;

				var activeZoomTween = camera == camHUD ? cameraHudZoomTween : cameraZoomTween;
				if (activeZoomTween != null)
					activeZoomTween.cancel();
				if (camera == camHUD)
					cameraHudZoomTween = null;
				else
					cameraZoomTween = null;

				if (!shouldTween || ease.toUpperCase() == "INSTANT" || ease.toUpperCase() == "CLASSIC" || duration <= 0)
				{
					camera.zoom = targetZoom;
					if (camera == camHUD)
						hudDefaultZoom = targetZoom;
					else
						gameDefaultZoom = targetZoom;
				}
				else
				{
					var zoomTween = FlxTween.tween(camera, {zoom: targetZoom},
						duration * Conductor.stepCrochet / 1000, {
							ease: getCameraEase(ease, easeDir),
							onComplete: function(_)
							{
								if (camera == camHUD)
								{
									hudDefaultZoom = targetZoom;
									cameraHudZoomTween = null;
								}
								else
								{
									gameDefaultZoom = targetZoom;
									cameraZoomTween = null;
								}
							}
						});
					if (camera == camHUD)
						cameraHudZoomTween = zoomTween;
					else
						cameraZoomTween = zoomTween;
				}
			case "Camera Beat Interval Change":
				camZoomingStrength = event.values[0];
				camZoomingInterval = event.values[1];
		}

		callScriptFunction("eventHit", [event]);
	}

	static function getCameraEase(ease:String, easeDir:String):EaseFunction
	{
		var easeName = ease.toLowerCase();
		var direction = easeDir;
		if (StringTools.endsWith(easeName, "inout"))
		{
			easeName = easeName.substr(0, easeName.length - "inout".length);
			direction = "InOut";
		}
		else if (StringTools.endsWith(easeName, "in"))
		{
			easeName = easeName.substr(0, easeName.length - "in".length);
			direction = "In";
		}
		else if (StringTools.endsWith(easeName, "out"))
		{
			easeName = easeName.substr(0, easeName.length - "out".length);
			direction = "Out";
		}

		var normalizedEase = switch (easeName)
		{
			case "smoothstep": "smoothStep";
			case "smootherstep": "smootherStep";
			default: easeName;
		};
		var normalizedDirection = switch (direction.toLowerCase())
		{
			case "in": "In";
			case "out": "Out";
			case "inout": "InOut";
			default: throw 'Camera event has unsupported ease direction "$direction".';
		};
		var resolvedEaseName = normalizedEase == "linear" ? "linear" : '$normalizedEase$normalizedDirection';
		var easeFunction:EaseFunction = cast Reflect.field(FlxEase, resolvedEaseName);
		if (easeFunction == null)
			throw 'Camera event has unsupported easing "$resolvedEaseName".';

		return easeFunction;
	}

	public static function loadSong(songName:String, songDifficulty:String = "hard")
	{
		curSong = songName;
		curDifficulty = songDifficulty;
		songData = Song.loadSong(curSong, curDifficulty);
	}
}
