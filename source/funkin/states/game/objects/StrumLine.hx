package funkin.states.game.objects;
//TODO: make some type of note skin system, 

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class StrumLine extends FlxTypedSpriteGroup<FlxSprite> {
    var data:LineData;
    var chartIndex:Int = 0;
    var pendingNotes:Array<NoteData> = [];
    var nextNoteIndex:Int = 0;
    public var isPlayerLine(default, null):Bool;
    public var notes:FlxTypedSpriteGroup<FlxSprite> = new FlxTypedSpriteGroup();
    public var characters:Array<Character> = [];
    var heldKeys:Array<Bool> = [false, false, false, false];

    public static var directionList:Array<String> = ["left", "down", "up", "right"];
    public static var seperation:Float = 120;
    public static var hitWindow:Float = 150;

    override public function new(x:Float, y:Float, ?data:LineData, chartIndex:Int = 0) {
        super(x, y);

        if (data != null) this.data = data;
        isPlayerLine = data != null && !data.cpu;
        this.chartIndex = chartIndex;

        for (i in 0...4) {
            var direction:String = directionList[i];

            var strum:Strum = new Strum(seperation * i, 0, direction);
            add(strum);
        }

        add(notes);

        pendingNotes = data.notes.copy();
        pendingNotes.sort(function(a:NoteData, b:NoteData):Int {
            return Reflect.compare(a.time, b.time);
        });
    }

    public function pressNote(direction:Int):Bool
    {
        if (!isPlayerLine || direction < 0 || direction >= directionList.length)
            return false;

        heldKeys[direction] = true;
        var target:Note = null;
        var closestDifference:Float = hitWindow + 1;

        for (member in notes.members)
        {
            if (member == null || !Std.isOfType(member, Note))
                continue;

            var note:Note = cast member;
            if (note.wasHit || note.noteData.direction != direction)
                continue;

            var difference:Float = Math.abs(Conductor.songPosition - note.noteData.time);
            if (difference <= hitWindow && difference < closestDifference)
            {
                target = note;
                closestDifference = difference;
            }
        }

        var receptor:Strum = cast members[direction];
        if (target == null)
        {
            receptor.playAnim("press", true);
            return false;
        }

        hitNote(target, receptor);
        return true;
    }

    public function updateKeyState(direction:Int, isHeld:Bool):Void
    {
        if (!isPlayerLine || direction < 0 || direction >= directionList.length)
            return;

        if (!isHeld && heldKeys[direction])
        {
            heldKeys[direction] = false;

            var sustainNotes:Array<Note> = [];
            for (member in notes.members)
            {
                if (member == null || !Std.isOfType(member, Note))
                    continue;

                var note:Note = cast member;
                if (note.wasHit && note.noteData.direction == direction && note.noteData.sustainLength > 0
                    && Conductor.songPosition < note.noteData.time + note.noteData.sustainLength)
                    sustainNotes.push(note);
            }

            for (note in sustainNotes)
            {
                var receptor:Strum = cast members[direction];
                receptor.endSustainConfirm();
                removeNote(note);
            }

            (cast members[direction] : Strum).playAnim("static", true);
        }
        else if (isHeld)
        {
            heldKeys[direction] = true;
            var receptor:Strum = cast members[direction];
            if (receptor.animation.curAnim == null || receptor.animation.curAnim.name == "static")
                receptor.playAnim("press", true);
        }
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
            var receptor:Strum = cast members[note.noteData.direction];

            var pixelsPerMs:Float = 0.45 * FlxMath.roundDecimal(data.scrollSpeed, 2);
            note.y = receptor.y - (Conductor.songPosition - note.noteData.time) * pixelsPerMs;
            var noteEndTime:Float = note.noteData.time + note.noteData.sustainLength;

            if (!note.wasHit && data.cpu && Conductor.songPosition >= note.noteData.time) {
                hitNote(note, receptor);
            }

            if (!note.wasHit && isPlayerLine && Conductor.songPosition > note.noteData.time + hitWindow) {
                removeNote(note);
                continue;
            }

            note.updateSustain(pixelsPerMs, receptor.y + receptor.height * 0.5, Conductor.songPosition);

            if (note.wasHit && note.noteData.sustainLength > 0 && Conductor.songPosition < noteEndTime) {
                if (isPlayerLine && !heldKeys[note.noteData.direction])
                {
                    receptor.endSustainConfirm();
                    removeNote(note);
                    continue;
                }

                for (char in characters) {
                    char.isSinging = true;
                    char.holdTimer = 0;
                }
            }

            if (note.wasHit && Conductor.songPosition >= noteEndTime) {
                if (note.noteData.sustainLength > 0)
                    receptor.endSustainConfirm();
                removeNote(note);
                i++;
                continue;
            }

            note.visible = !note.wasHit && note.y + note.height > 0 && note.y < FlxG.height;
            i++;
        }

        updateHeldReceptors();
    }

    function hitNote(note:Note, receptor:Strum):Void
    {
        note.wasHit = true;
        if (note.noteData.sustainLength > 0)
            receptor.beginSustainConfirm();
        receptor.playAnim("confirm", true);

        var animationName:String = 'sing${directionList[note.noteData.direction].toUpperCase()}';
        for (char in characters)
        {
            char.playAnim(animationName, true);
            char.isSinging = true;
            char.holdTimer = 0;
        }
    }

    function removeNote(note:Note):Void
    {
        if (note.sustainBody != null)
        {
            notes.remove(note.sustainBody);
            notes.remove(note.sustainEnd);
        }

        notes.remove(note);
        note.destroy();
    }

    function updateHeldReceptors():Void
    {
        if (!isPlayerLine)
            return;

        for (direction in 0...heldKeys.length)
        {
            if (!heldKeys[direction])
                continue;

            var receptor:Strum = cast members[direction];
            var sustaining:Bool = false;
            for (member in notes.members)
            {
                if (member == null || !Std.isOfType(member, Note))
                    continue;

                var note:Note = cast member;
                if (note.wasHit && note.noteData.direction == direction && note.noteData.sustainLength > 0)
                {
                    sustaining = true;
                    break;
                }
            }

            if (!sustaining && receptor.animation.curAnim != null && receptor.animation.curAnim.name == "static")
                receptor.playAnim("press", true);
        }
    }

    function spawnNotes():Void
    {
        var pixelsPerMs:Float = 0.45 * FlxMath.roundDecimal(data.scrollSpeed, 2);
        var spawnBoundary:Float = FlxG.height + 150 - y;

        while (nextNoteIndex < pendingNotes.length)
        {
            var noteData:NoteData = pendingNotes[nextNoteIndex];
            var receptor:Strum = cast members[noteData.direction];
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