package funkin.states.game.objects;

class Note extends FlxSprite {
    public var noteData:NoteData;
    public var sustainBody:FlxSprite = null;
    public var sustainEnd:FlxSprite = null;
    public var wasHit:Bool = false;
    public static var directionList:Array<String> = ["left", "down", "up", "right"];

    override public function new(x:Float, y:Float, noteData:NoteData) {
        super(x, y);
        this.noteData = noteData;

        frames = Paths.getSparrowAtlas("game/notes");

        var direction:String = directionList[noteData.direction];
        animation.addByPrefix("note", '$direction note');
        animation.addByPrefix("sustain", '$direction sustain0');
        animation.addByPrefix("sustain end", '$direction sustain end');
        animation.play("note", true);
        antialiasing = true;

        setGraphicSize(Std.int(frameWidth * 0.75));
        updateHitbox();

        if (noteData.sustainLength > 0)
        {
            sustainBody = new FlxSprite();
            sustainBody.frames = frames;
            sustainBody.animation.addByPrefix("sustain", '$direction sustain0');
            sustainBody.animation.play("sustain");
            sustainBody.antialiasing = antialiasing;
            sustainBody.scale.x = 0.75;
            sustainBody.updateHitbox();

            sustainEnd = new FlxSprite();
            sustainEnd.frames = frames;
            sustainEnd.animation.addByPrefix("sustain end", '$direction sustain end');
            sustainEnd.animation.play("sustain end");
            sustainEnd.antialiasing = sustainBody.antialiasing;
            sustainEnd.setGraphicSize(Std.int(sustainEnd.frameWidth * 0.75));
            sustainEnd.updateHitbox();
        }
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);
    }

    public function updateSustain(pixelsPerMs:Float, receptorCenterY:Float, songPosition:Float):Void
    {
        if (sustainBody == null || sustainEnd == null)
            return;

        var sustainStartY:Float = wasHit ? receptorCenterY : y + height * 0.5;
        var sustainEndY:Float = receptorCenterY - (songPosition - noteData.time - noteData.sustainLength) * pixelsPerMs;
        var remainingHeight:Float = Math.max(0, sustainEndY - sustainStartY);
        var sustainEndScale:Float = Math.min(0.75, remainingHeight / sustainEnd.frameHeight);
        var sustainEndHeight:Float = sustainEnd.frameHeight * sustainEndScale;
        var bodyHeight:Float = Math.max(0, remainingHeight - sustainEndHeight);

        sustainBody.scale.set(0.75, Math.max(1, bodyHeight) / sustainBody.frameHeight);
        sustainBody.updateHitbox();
        sustainBody.x = x + (width - sustainBody.width) * 0.5;
        sustainBody.y = sustainStartY;
        sustainBody.visible = bodyHeight > 0 && sustainBody.y + bodyHeight > 0 && sustainBody.y < FlxG.height;

        sustainEnd.scale.y = sustainEndScale;
        sustainEnd.updateHitbox();
        sustainEnd.x = x + (width - sustainEnd.width) * 0.5;
        sustainEnd.y = sustainEndY - sustainEndHeight;
        sustainEnd.visible = remainingHeight > 0 && sustainEndY > 0 && sustainEnd.y < FlxG.height;
    }

    override public function destroy():Void
    {
        if (sustainBody != null)
        {
            sustainBody.destroy();
            sustainBody = null;
        }
        if (sustainEnd != null)
        {
            sustainEnd.destroy();
            sustainEnd = null;
        }
        super.destroy();
    }
}