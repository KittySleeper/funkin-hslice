package funkin.states.game.objects;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class StrumLine extends FlxTypedSpriteGroup<FlxSprite> {
    var data:LineData;
    var chartIndex:Int = 0;
    public var notes:FlxTypedGroup<Note> = new FlxTypedGroup();
    public var characters:Array<Character> = [];

    public static var directionList:Array<String> = ["left", "down", "up", "right"];
    public static var seperation:Float = 120;

    override public function new(x:Float, y:Float, ?data:LineData, chartIndex:Int = 0) {
        super(x, y);

        if (data != null) this.data = data;
        this.chartIndex = chartIndex;

        for (i in 0...4) {
            var direction:String = directionList[i];

            var strum:FlxSprite = new FlxSprite(seperation * i);
            strum.frames = Paths.getSparrowAtlas("game/receptors");
            strum.animation.addByPrefix("static", '$direction static', 24);
            strum.animation.addByPrefix("press", '$direction press', 24);
            strum.animation.addByPrefix("confirm", '$direction confirm', 24);
            strum.animation.play("static", true);
            strum.antialiasing = true;
            strum.setGraphicSize(Std.int(strum.frameWidth * 0.75));
            strum.updateHitbox();
            add(strum);
        }

        for (noteData in data.notes) {
            var receptor:FlxSprite = members[noteData.direction];
            var note:Note = new Note(receptor.x - x, receptor.y - y, noteData);
            notes.add(note);
            add(note);
        }
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        var i:Int = 0;

        while (i <= notes.members.length) {
            var note:Note = notes.members[i];
            if (note == null) {
                i++;
                continue;
            }

            note.y = (members[note.noteData.direction].y - (Conductor.songPosition - note.noteData.time) * (0.45 * FlxMath.roundDecimal(data.scrollSpeed, 2)));

            if (Conductor.songPosition >= note.noteData.time) {
                var direction:Int = note.noteData.direction;
                notes.remove(note, true);
                remove(note);
                
                for (char in characters) {
                    char.playAnim('sing${directionList[direction].toUpperCase()}', true);
                    char.isSinging = true;
                    char.holdTimer = 0;
                }

                note.destroy();
                i++;
                continue;
            }

            note.exists = note.visible = note.y + note.height > 0 && note.y < FlxG.height;
            i++;
        }
    }
}