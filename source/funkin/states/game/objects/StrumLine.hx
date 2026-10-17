package funkin.states.game.objects;
//TODO: make some type of note skin system, 

import flixel.input.keyboard.FlxKey;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import openfl.events.KeyboardEvent;

class StrumLine extends FlxTypedSpriteGroup<FlxSprite> {
    var data:LineData;
    var chartIndex:Int = 0;
    var pendingNotes:Array<NoteData> = [];
    var nextNoteIndex:Int = 0;
    var notesByDirection:Array<Array<Note>> = [[], [], [], []];
    var activeSplashes:Array<NoteSplash> = [];
    var activeSustainCovers:Array<SustainCover> = [];
    var sustainCoversByDirection:Array<SustainCover> = [null, null, null, null];
    public var isPlayerLine(default, null):Bool = false;
    public var notes:FlxTypedSpriteGroup<FlxSprite> = new FlxTypedSpriteGroup();
    public var characters:Array<Character> = [];
    public var onJudgement:RatingData->Void;
    var heldKeys:Array<Bool> = [false, false, false, false];
    var physicalKeys:Array<Bool> = [false, false, false, false];
    var inputEvents:Array<{direction:Int, isDown:Bool}> = [];
    var keyDownHandler:KeyboardEvent->Void;
    var keyUpHandler:KeyboardEvent->Void;

    public static var directionList:Array<String> = ["left", "down", "up", "right"];
    public static var seperation:Float = 120;
    public static var ratings:Array<RatingData> = [
        {name: "sick", sprite: "sick", timingWindow: 45, accuracyWeight: 1, score: 350, health: 4, shouldSplash: true},
        {name: "good", sprite: "good", timingWindow: 90, accuracyWeight: 0.75, score: 200, health: 2, shouldSplash: false},
        {name: "bad", sprite: "bad", timingWindow: 135, accuracyWeight: 0.5, score: 100, health: -2, shouldSplash: false},
        {name: "shit", sprite: "shit", timingWindow: 150, accuracyWeight: 0.25, score: 50, health: -4, shouldSplash: false}
    ];
    public static var missRating:RatingData = {
        name: "miss",
        sprite: "",
        timingWindow: 0,
        accuracyWeight: 0,
        score: -150,
        health: -4,
        shouldSplash: false
    };
    public static var hitWindow(get, never):Float;

    static function get_hitWindow():Float
    {
        var window:Float = 0;
        for (rating in ratings)
            window = Math.max(window, rating.timingWindow);
        return window;
    }

    override public function new(x:Float, y:Float, ?data:LineData, chartIndex:Int = 0) {
        super(x, y);

        if (data != null) this.data = data;
        isPlayerLine = data != null && !data.cpu;
        this.chartIndex = chartIndex;

        if (isPlayerLine) {
            keyDownHandler = onKeyDown;
            keyUpHandler = onKeyUp;
            FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
            FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyUpHandler);
            FlxG.signals.focusLost.add(onFocusLost);
        }

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

    function onKeyDown(event:KeyboardEvent):Void
    {
        var direction:Int = directionFromKey(event.keyCode);
        if (direction < 0 || physicalKeys[direction])
            return;

        physicalKeys[direction] = true;
        inputEvents.push({direction: direction, isDown: true});
    }

    function onKeyUp(event:KeyboardEvent):Void
    {
        var direction:Int = directionFromKey(event.keyCode);
        if (direction < 0 || !physicalKeys[direction])
            return;

        physicalKeys[direction] = false;
        inputEvents.push({direction: direction, isDown: false});
    }

    function onFocusLost():Void
    {
        for (direction in 0...physicalKeys.length)
        {
            if (!physicalKeys[direction])
                continue;

            physicalKeys[direction] = false;
            inputEvents.push({direction: direction, isDown: false});
        }
    }

    function directionFromKey(keyCode:Int):Int
    {
        return switch (keyCode) {
            case FlxKey.A: 0;
            case FlxKey.S: 1;
            case FlxKey.W: 2;
            case FlxKey.D: 3;
            default: -1;
        };
    }

    public function pressNote(direction:Int):Bool
    {
        if (!isPlayerLine || direction < 0 || direction >= directionList.length)
            return false;

        heldKeys[direction] = true;
        (cast members[direction] : Strum).isHeld = true;
        var directionNotes:Array<Note> = notesByDirection[direction];
        while (directionNotes.length > 0)
        {
            var target:Note = directionNotes[0];
            var timeDifference:Float = Conductor.songPosition - target.noteData.time;
            if (timeDifference > hitWindow)
            {
                registerJudgement(missRating);
                removeNote(target);
                continue;
            }

            if (timeDifference < -hitWindow)
                break;

            hitNote(target, cast members[direction]);
            return true;
        }

        var receptor:Strum = cast members[direction];
        receptor.playAnim("press", true);
        return false;
    }

    override public function destroy():Void
    {
        if (isPlayerLine)
        {
            FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
            FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyUpHandler);
            FlxG.signals.focusLost.remove(onFocusLost);
        }

        super.destroy();
    }

    public function updateKeyState(direction:Int, isHeld:Bool):Void
    {
        if (!isPlayerLine || direction < 0 || direction >= directionList.length)
            return;

        if (!isHeld && heldKeys[direction])
        {
            heldKeys[direction] = false;
            var receptor:Strum = cast members[direction];
            receptor.isHeld = false;

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
                receptor.endSustainConfirm();
                removeNote(note);
            }

            stopSustainCover(direction);
            receptor.playAnim("static", true);
        }
        else if (isHeld)
        {
            heldKeys[direction] = true;
            var receptor:Strum = cast members[direction];
            receptor.isHeld = true;
            if (receptor.animation.curAnim == null || receptor.animation.curAnim.name == "static")
                receptor.playAnim("press", true);
        }
    }

    override public function update(elapsed:Float) {
        spawnNotes();
        processInputEvents();
        super.update(elapsed);
        cleanupFinishedSplashes();
        cleanupFinishedSustainCovers();

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
            note.y = receptor.y - (Conductor.visualSongPosition - note.noteData.time) * pixelsPerMs;
            var noteEndTime:Float = note.noteData.time + note.noteData.sustainLength;

            if (!note.wasHit && !isPlayerLine && Conductor.songPosition >= note.noteData.time) {
                hitNote(note, receptor);
            }

            if (!note.wasHit && isPlayerLine && Conductor.songPosition > note.noteData.time + hitWindow) {
                registerJudgement(missRating);
                removeNote(note);
                continue;
            }

            note.updateSustain(pixelsPerMs, receptor.y + receptor.height * 0.5, Conductor.visualSongPosition);

            if (note.wasHit && note.noteData.sustainLength > 0 && Conductor.songPosition < noteEndTime) {
                if (isPlayerLine && !heldKeys[note.noteData.direction])
                {
                    receptor.endSustainConfirm();
                    removeNote(note);
                    stopSustainCover(note.noteData.direction);
                    continue;
                }

                for (char in characters) {
                    char.isSinging = true;
                    char.holdTimer = 0;
                }
            }

            if (note.wasHit && Conductor.songPosition >= noteEndTime) {
                if (note.noteData.sustainLength > 0)
                {
                    receptor.endSustainConfirm();
                    var direction:Int = note.noteData.direction;
                    removeNote(note);
                    if (!hasActiveSustain(direction))
                        stopSustainCover(direction);
                    i++;
                    continue;
                }
                removeNote(note);
                i++;
                continue;
            }

            note.visible = !note.wasHit && note.y + note.height > 0 && note.y < FlxG.height;
            i++;
        }

        updateHeldReceptors();
    }

    function processInputEvents():Void
    {
        for (inputEvent in inputEvents)
        {
            if (inputEvent.isDown)
                pressNote(inputEvent.direction);
            else
                updateKeyState(inputEvent.direction, false);
        }

        inputEvents.resize(0);
    }

    function hitNote(note:Note, receptor:Strum):Void
    {
        note.wasHit = true;
        notesByDirection[note.noteData.direction].remove(note);
        if (isPlayerLine)
        {
            var offset:Float = Conductor.songPosition - note.noteData.time;
            var rating:RatingData = ratingForOffset(offset);
            registerJudgement(rating);
            if (rating.shouldSplash)
                showNoteSplash(receptor, note.noteData.direction);
        }

        if (note.noteData.sustainLength > 0)
        {
            receptor.beginSustainConfirm();
            startSustainCover(receptor, note.noteData.direction);
        }
        receptor.playAnim("confirm", true);

        var animationName:String = 'sing${directionList[note.noteData.direction].toUpperCase()}';
        for (char in characters)
        {
            char.playAnim(animationName, true);
            char.isSinging = true;
            char.holdTimer = 0;
        }
    }

    function showNoteSplash(receptor:Strum, direction:Int):Void
    {
        var splash:NoteSplash = new NoteSplash(0, 0, direction);
        splash.x = receptor.x - x + (receptor.width - splash.width) * 0.5;
        splash.y = receptor.y - y + (receptor.height - splash.height) * 0.5;
        activeSplashes.push(splash);
        add(splash);
    }

    function cleanupFinishedSplashes():Void
    {
        var i:Int = activeSplashes.length - 1;
        while (i >= 0)
        {
            var splash:NoteSplash = activeSplashes[i];
            if (!splash.alive || splash.isFinished)
            {
                activeSplashes.splice(i, 1);
                remove(splash, true);
                splash.destroy();
            }
            i--;
        }
    }

    function startSustainCover(receptor:Strum, direction:Int):Void
    {
        var currentCover:SustainCover = sustainCoversByDirection[direction];
        if (currentCover != null && currentCover.alive && !currentCover.isEnding)
            return;

        var cover:SustainCover = new SustainCover(0, 0, direction);
        sustainCoversByDirection[direction] = cover;
        activeSustainCovers.push(cover);
        add(cover);
        cover.centerOn(receptor.x + receptor.width * 0.5, receptor.y + receptor.height * 0.5);
    }

    function stopSustainCover(direction:Int):Void
    {
        var cover:SustainCover = sustainCoversByDirection[direction];
        if (cover == null)
            return;

        sustainCoversByDirection[direction] = null;
        cover.finish();
    }

    function cleanupFinishedSustainCovers():Void
    {
        var i:Int = activeSustainCovers.length - 1;
        while (i >= 0)
        {
            var cover:SustainCover = activeSustainCovers[i];
            if (!cover.alive || cover.isFinished)
            {
                activeSustainCovers.splice(i, 1);
                remove(cover, true);
                cover.destroy();
            }
            i--;
        }
    }

    function hasActiveSustain(direction:Int):Bool
    {
        for (member in notes.members)
        {
            if (member == null || !Std.isOfType(member, Note))
                continue;

            var note:Note = cast member;
            if (note.wasHit && note.noteData.direction == direction && note.noteData.sustainLength > 0
                && Conductor.songPosition < note.noteData.time + note.noteData.sustainLength)
                return true;
        }

        return false;
    }

    function ratingForOffset(offset:Float):RatingData
    {
        var absoluteOffset:Float = Math.abs(offset);
        for (rating in ratings)
            if (absoluteOffset <= rating.timingWindow)
                return rating;
        return missRating;
    }

    function registerJudgement(rating:RatingData):Void
    {
        if (isPlayerLine && onJudgement != null)
            onJudgement(rating);
    }

    function removeNote(note:Note):Void
    {
        notesByDirection[note.noteData.direction].remove(note);

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

            // if (!sustaining && receptor.animation.curAnim != null && receptor.animation.curAnim.name == "static")
            //     receptor.playAnim("press", true);
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
            notesByDirection[noteData.direction].push(note);
            nextNoteIndex++;
        }
    }
}

typedef RatingData =
{
    var name:String;
    var sprite:String;
    var timingWindow:Float;
    var accuracyWeight:Float;
    var score:Int;
    var health:Float;
    var shouldSplash:Bool;
}