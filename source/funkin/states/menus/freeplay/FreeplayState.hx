package funkin.states.menus.freeplay;

import funkin.states.game.PlayState;
import flixel.FlxBasic;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

class FreeplayState extends MusicBeatState {
    public static var songs:Array<SongMetaData> = [];

    var songObjects:FlxTypedSpriteGroup<Dynamic> = new FlxTypedSpriteGroup();
    static var curSelected:Int = 0;

    public override function new() {
        super();
        trace(loadSongList());

        add(songObjects);

        for (i => song in songs) {
            var txt:FlxText = new FlxText(0, i * 105, FlxG.width, song.displayName, 35);
            txt.alignment = CENTER;
            songObjects.add(txt);
        }
    }

    public override function update(elapsed:Float) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S) curSelected = FlxMath.wrap(curSelected + 1, 0, songObjects.members.length - 1);
        if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W) curSelected = FlxMath.wrap(curSelected - 1, 0, songObjects.members.length - 1);
        FlxG.camera.scroll.y = CoolUtil.coolLerp(songObjects.members[curSelected].y, FlxG.camera.scroll.y, 0.35, elapsed);

        if (FlxG.keys.justPressed.ENTER) {
            PlayState.loadSong(songs[curSelected].name, songs[curSelected].difficulties[songs[curSelected].difficulties.length - 1]);
            FlxG.switchState(() -> new PlayState());
        }
    }

    public static function loadSongList():Array<SongMetaData> {
        songs.clear();

        for (song in Paths.readDirectory("songs")) {
            var meta:SongMetaData;

            if (Paths.exists('songs/$song/meta.json')) {
                meta = Paths.json('songs/$song/meta');
                meta.name = song;
            } else {
                var difficulties:Array<String> = [];

                if (Paths.exists('songs/$song/charts'))
                    difficulties = Paths.readDirectory('songs/$song/charts');
                else 
                    difficulties = [];

                for (i in 0...difficulties.length)
                    difficulties[i] = difficulties[i].replace(".json", "");
                    
                meta = {
                    name: song,
                    displayName: song,
                    difficulties: difficulties,
                    icon: "face",
                    color: FlxColor.GRAY.toHexString()
                };
            }

            songs.push(meta);
        }

        return songs;
    }
}