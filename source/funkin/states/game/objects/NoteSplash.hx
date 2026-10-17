package funkin.states.game.objects;

class NoteSplash extends FlxSprite
{
	public function new(x:Float, y:Float, noteData:Int = 0)
	{
		super(x, y);

		var color:String = switch (noteData)
		{
			case 0: "purple";
			case 1: "blue";
			case 2: "green";
			case 3: "red";
			default: throw 'Invalid note splash direction: $noteData.';
		};

		frames = Paths.getSparrowAtlas("game/splashes");
		var variant:Int = FlxG.random.int(1, 2);
		animation.addByPrefix("splash", 'note impact $variant $color', 24, false);
		animation.play("splash", true);
		animation.curAnim.frameRate += FlxG.random.int(-2, 2);
		antialiasing = true;
		alpha = 0.6;
		setGraphicSize(Std.int(frameWidth * 0.7));
		updateHitbox();
		offset.set(width * 0.3, height * 0.3);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (animation.curAnim != null && animation.curAnim.finished)
			kill();
	}

	public var isFinished(get, never):Bool;

	function get_isFinished():Bool
		return !alive || (animation.curAnim != null && animation.curAnim.finished);
}
