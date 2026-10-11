package funkin.states.game.objects;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class StrumLine extends FlxTypedSpriteGroup<FlxSprite> {
    var data:LineData;
    var chartIndex:Int = 0;
    var pendingNotes:Array<NoteData> = [];
    var nextNoteIndex:Int = 0;
    public var notes:FlxTypedSpriteGroup<FlxSprite> = new FlxTypedSpriteGroup();
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

        add(notes);

        pendingNotes = data.notes.copy();
        pendingNotes.sort(function(a:NoteData, b:NoteData):Int {
            return Reflect.compare(a.time, b.time);
        });
    }

    override public function update(elapsed:Float) {
        spawnNotes();
        super.update(elapsed);

        var i:Int = 0;

        while (i < notes.members.length) {
            var member:FlxSprite = notes.members[i];
            if (member == null || !Std.isOfType(member, Note)) {
                i++;
                continue;
            }

            var note:Note = cast member;
            var receptor:FlxSprite = members[note.noteData.direction];

            var pixelsPerMs:Float = 0.45 * FlxMath.roundDecimal(data.scrollSpeed, 2);
            note.y = receptor.y - (Conductor.songPosition - note.noteData.time) * pixelsPerMs;
            var noteEndTime:Float = note.noteData.time + note.noteData.sustainLength;

            if (!note.wasHit && Conductor.songPosition >= note.noteData.time) {
                note.wasHit = true;
                var direction:Int = note.noteData.direction;
                var animationName:String = 'sing${directionList[direction].toUpperCase()}';

                for (char in characters) {
                    char.playAnim(animationName, true);
                    char.isSinging = true;
                    char.holdTimer = 0;
                }
            }

            note.updateSustain(pixelsPerMs, receptor.y + receptor.height * 0.5, Conductor.songPosition);

            if (note.wasHit && note.noteData.sustainLength > 0 && Conductor.songPosition < noteEndTime) {
                for (char in characters) {
                    char.isSinging = true;
                    char.holdTimer = 0;
                }
            }

            if (note.wasHit && Conductor.songPosition >= noteEndTime) {
                if (note.sustainBody != null) {
                    notes.remove(note.sustainBody);
                    notes.remove(note.sustainEnd);
                }
                notes.remove(note);
                note.destroy();
                i++;
                continue;
            }

            note.visible = !note.wasHit && note.y + note.height > 0 && note.y < FlxG.height;
            i++;
        }
    }

    function spawnNotes():Void
    {
        var pixelsPerMs:Float = 0.45 * FlxMath.roundDecimal(data.scrollSpeed, 2);
        var spawnBoundary:Float = FlxG.height + 150 - y;

        while (nextNoteIndex < pendingNotes.length)
        {
            var noteData:NoteData = pendingNotes[nextNoteIndex];
            var receptor:FlxSprite = members[noteData.direction];
            var spawnTime:Float = noteData.time;

            if (pixelsPerMs > 0)
                spawnTime -= (spawnBoundary - receptor.y) / pixelsPerMs;

            if (Conductor.songPosition < spawnTime)
                break;

            var note:Note = new Note(receptor.x - x, receptor.y - y, noteData);
            if (note.sustainBody != null)
            {
                notes.add(note.sustainBody);
                notes.add(note.sustainEnd);
            }
            notes.add(note);
            nextNoteIndex++;
        }
    }
}