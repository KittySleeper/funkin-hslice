package funkin.states.game.objects;

class SustainCover extends FlxSprite
{
	public var isEnding(default, null):Bool = false;
	var centerX:Float = 0;
	var centerY:Float = 0;

	public function new(x:Float, y:Float, direction:Int)
	{
		super(x, y);

		var directionName:String = switch (direction)
		{
			case 0: "left";
			case 1: "down";
			case 2: "up";
			case 3: "right";
			default: throw 'Invalid sustain cover direction: $direction.';
		};

		frames = Paths.getSparrowAtlas("game/holdcovers");
		animation.addByPrefix("start", 'start $directionName', 24, false);
		animation.addByPrefix("loop", directionName, 24, true);
		animation.addByPrefix("end", 'end $directionName', 24, false);
		animation.play("start", true);
		antialiasing = true;
		updateHitbox();
	}

	public function centerOn(x:Float, y:Float):Void
	{
		centerX = x;
		centerY = y;
		centerVisibleFrame();
	}

	public function finish():Void
	{
		if (isEnding)
			return;

		isEnding = true;
		animation.play("end", true);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (animation.curAnim == null)
			return;

		if (!isEnding && animation.curAnim.name == "start" && animation.curAnim.finished)
			animation.play("loop", true);
		else if (isEnding && animation.curAnim.finished)
			kill();

		centerVisibleFrame();
	}

	function centerVisibleFrame():Void
	{
		if (frame == null)
			return;

		x = centerX - (frame.offset.x + frame.frame.width * 0.5) * scale.x;
		y = centerY - (frame.offset.y + frame.frame.height * 0.5) * scale.y;
	}

	public var isFinished(get, never):Bool;

	function get_isFinished():Bool
		return !alive || (isEnding && animation.curAnim != null && animation.curAnim.finished);
}
