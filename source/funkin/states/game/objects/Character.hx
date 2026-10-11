package funkin.states.game.objects;

import animate.FlxAnimate;

class Character extends FlxAnimate
{
	public var animOffsets:Map<String, Array<Dynamic>> = new Map<String, Array<Dynamic>>();
	public var isPlayer:Bool = false;
	public var isSinging:Bool = false;
	public var characterName:String = "bf";
	public var holdTimer:Float = 0;

	public var characterData:CharacterData = {
		imagePath: "",
		imageType: "",
		iconPath: "",
		swapAnimsIfPlayer: true,
		danceSteps: [],
		animations: [],
		cameraOffset: [],
		position: [],
		healthColor: FlxColor.GRAY.toHexString(false),
		scale: 1,
		singTimer: 4,
		flipX: false,
		flipY: false,
		antialiasing: true,
		format: "HSlice Format"
	};

	override public function new(x:Float, y:Float, characterName:String = "bf", isPlayer:Bool = false)
	{
		this.characterName = characterName;
		this.isPlayer = isPlayer;

		var characterFolder:String = Paths.exists('characters/$characterName/data.json') ? characterName : "bf";
		var charJson:Dynamic = Paths.json('characters/$characterFolder/data');

		if (charJson.format != null && charJson.format == "HSlice Format")
		{ // HSlice / Better Than VSlice
			characterData = charJson;
		}
		else if (charJson.healthbar_colors != null)
		{ // Psych
			characterData.imagePath = "sprite";
			characterData.imageType = "sparrow";
			characterData.danceSteps = ["idle"];
			characterData.position = charJson.position != null ? charJson.position : [0, 0];
			characterData.healthColor = FlxColor.fromRGB(charJson.healthbar_colors[0], charJson.healthbar_colors[1], charJson.healthbar_colors[2])
				.toHexString(false);
			characterData.cameraOffset = charJson.camera_position;
			characterData.scale = charJson.scale;
			characterData.singTimer = charJson.sing_duration;
			characterData.antialiasing = !charJson.no_antialiasing;
			characterData.flipX = charJson.flip_x;
			characterData.flipY = false;

			for (anim in cast(charJson.animations, Array<Dynamic>))
			{
				var animationData:AnimationData = {
					prefix: anim.anim,
					postfix: anim.name,
					looped: anim.loop,
					fps: anim.fps,
					indices: anim.indices,
					offset: [Std.parseFloat(anim.offsets[0]), Std.parseFloat(anim.offsets[1])]
				}
				characterData.animations.push(animationData);

				if (anim.anim == "danceLeft" || anim.anim == "danceRight")
					characterData.danceSteps = ["danceLeft", "danceRight"];
			}
		}

		super(x + characterData.position[0], y + characterData.position[1]);

		switch (characterData.imageType)
		{
			case "atlas":
				frames = Paths.getAnimateAtlas(characterData.imagePath, 'characters/$characterFolder');
			default:
				frames = Paths.getSparrowAtlas(characterData.imagePath, 'characters/$characterFolder');
				for (anim in characterData.animations)
				{
					animation.addByPrefix(anim.prefix, anim.postfix, anim.fps, anim.looped);
					animOffsets.set(anim.prefix, anim.offset);
				}
		}

		antialiasing = characterData.antialiasing;
		flipY = characterData.flipY;
		flipX = characterData.flipX;

		if (isPlayer)
		{
			flipX = !flipX;

			if (animation != null && characterData.swapAnimsIfPlayer)
			{
				// var animArray
				var oldRight = animation.getByName("singRIGHT").frames;
				var oldRightOffset = animOffsets.get("singRIGHT");
				animation.getByName("singRIGHT").frames = animation.getByName("singLEFT").frames;
				animOffsets.set("singRIGHT", animOffsets.get("singLEFT"));
				animation.getByName('singLEFT').frames = oldRight;
				animOffsets.set("singLEFT", oldRightOffset);

				// IF THEY HAVE MISS ANIMATIONS??
				if (animation.getByName('singRIGHTmiss') != null)
				{
					var oldMiss = animation.getByName("singRIGHTmiss").frames;
					var oldMissOffset = animOffsets.get("singRIGHTmiss");
					animation.getByName("singRIGHTmiss").frames = animation.getByName("singLEFTmiss").frames;
					animOffsets.set("singRIGHTmiss", animOffsets.get("singLEFTmiss"));
					animation.getByName('singLEFTmiss').frames = oldMiss;
					animOffsets.set("singLEFTmiss", oldMissOffset);
				}
			}
		}

		dance(true);

		setGraphicSize(frameWidth * characterData.scale);
		updateHitbox();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isSinging)
		{
			holdTimer += elapsed;
		}

		if (holdTimer >= Conductor.stepCrochet * characterData.singTimer * 0.001)
		{
			dance();
			holdTimer = 0;
			isSinging = false;
		}
	}

	public function playAnim(name:String, forced:Bool = false, reversed:Bool = false)
	{
		if (!animation.exists(name))
			return;
		animation.play(name, forced, reversed);
		offset.set(animOffsets.get(name)[0], animOffsets.get(name)[1]);
	}

	public var danceStep:Int = 0;

	public function dance(forced:Bool = true)
	{
		danceStep = Std.int(FlxMath.bound(danceStep++, 0, characterData.danceSteps.length - 1));
		playAnim(characterData.danceSteps[danceStep]);
	}
}

typedef CharacterData =
{
	imagePath:String,
	imageType:String,
	iconPath:String,
	danceSteps:Array<String>,
	swapAnimsIfPlayer:Bool,
	animations:Array<AnimationData>,
	cameraOffset:Array<Float>,
	position:Array<Float>,
	healthColor:String,
	scale:Float,
	singTimer:Float,
	flipX:Bool,
	flipY:Bool,
	antialiasing:Bool,
	format:String
}

typedef AnimationData =
{
	prefix:String,
	postfix:String,
	offset:Array<Float>,
	indices:Array<Int>,
	looped:Bool,
	fps:Int
}
