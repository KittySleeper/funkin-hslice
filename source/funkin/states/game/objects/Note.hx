package funkin.states.game.objects;

class Note extends FlxSprite {
    public var noteData:NoteData;
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

        setGraphicSize(Std.int(frameWidth * 0.75));
        updateHitbox();
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);
    }
}