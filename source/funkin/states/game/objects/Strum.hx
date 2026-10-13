package funkin.states.game.objects;

class Strum extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	var sustainConfirmCount:Int = 0;

	public function new(x:Float, y:Float, direction:String)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas("game/receptors");
		animation.addByPrefix("static", '$direction static', 24);
		animation.addByPrefix("press", '$direction press', 24, false);
		animation.addByPrefix("confirm", '$direction confirm', 24, false);

		for (animName in ["static", "press", "confirm"])
			animOffsets.set(animName, [0, 0]);

		antialiasing = true;
		playAnim("static", true);
		setGraphicSize(Std.int(frameWidth * 0.75));
		updateHitbox();

		var staticOffsetX:Float = offset.x;
		var staticOffsetY:Float = offset.y;
		var staticFrame = frames.frames[animation.getByName("static").frames[0]];
		var pressFrame = frames.frames[animation.getByName("press").frames[0]];
		var confirmFrame = frames.frames[animation.getByName("confirm").frames[0]];
		animOffsets.set("static", [staticOffsetX, staticOffsetY]);
		animOffsets.set("press", [
			staticOffsetX + (pressFrame.sourceSize.x - staticFrame.sourceSize.x) * scale.x * 0.5,
			staticOffsetY + (pressFrame.sourceSize.y - staticFrame.sourceSize.y) * scale.y * 0.5
		]);
		animOffsets.set("confirm", [
			staticOffsetX + (confirmFrame.sourceSize.x - staticFrame.sourceSize.x) * scale.x * 0.5,
			staticOffsetY + (confirmFrame.sourceSize.y - staticFrame.sourceSize.y) * scale.y * 0.5
		]);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sustainConfirmCount == 0 && animation.curAnim != null && animation.curAnim.name == "confirm" && animation.curAnim.finished)
			playAnim("static", true);
	}

	public function beginSustainConfirm():Void
	{
		sustainConfirmCount++;
	}

	public function endSustainConfirm():Void
	{
		if (sustainConfirmCount > 0)
			sustainConfirmCount--;
	}

	public function playAnim(name:String, forced:Bool = false, reversed:Bool = false):Void
	{
		if (!animation.exists(name))
			return;

		animation.play(name, forced, reversed);
		var animOffset:Array<Float> = animOffsets.get(name);
		if (animOffset != null)
			offset.set(animOffset[0], animOffset[1]);
	}
}
