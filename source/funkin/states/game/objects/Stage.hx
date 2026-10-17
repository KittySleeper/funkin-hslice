package funkin.states.game.objects;

import funkin.backend.HScript;
import flixel.group.FlxContainer;

/**
 * Makes A Stage, You Need Too Call
 ```haxe
 stage.addObjects()
 ```
 In Order Too Really Actually Use It.
 This System Is Sorta Scuffed
 I Wanna Eventually Rewrite It Probs But I Couldn't Think Of A Better Way For Z-Indexing Other Than Making Some Weird FlxSprite Thing, But That Will Be On My To-Do For Later.
**/
class Stage {
    public var container:FlxContainer;
    public var stageName:String = "stage";
    public var stageData:StageData;

    public var stageObjects:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    public var stageScripts:Array<HScript> = [];

    public function new(stageName:String = "stage", ?container:FlxContainer) {
        this.container = container == null ? FlxG.state : container;
        this.stageName = stageName;
        stageData = Paths.exists('stages/$stageName/data.json') ? Paths.json('stages/$stageName/data') : Paths.json('stages/stage/data');
        if (stageData.imagePath == null) stageData.imagePath = 'stages/$stageName/assets';

        for (scriptName in Paths.readDirectory('stages/$stageName/scripts'))
		{
			var scriptType:String = "";

			for (fileType in HScript.supportedFileTypes)
			{
				if (scriptName.endsWith('.$fileType'))
					scriptType = "haxe";
			}

			if (scriptType == "haxe") {
                var state:MusicBeatState = cast(FlxG.state, MusicBeatState);

				var script:HScript = state.createHScript('stages/$stageName/scripts/$scriptName', false, false);
                script.set("add", container.add);
                script.set("remove", container.remove);
                script.set("insert", container.insert);
                script.set("this", this);
                if (script.exists("create"))
                    script.call("create");
                state.haxescripts.push(script);
                stageScripts.push(script);
            }
		}
    }

    public function getCharacterData(charName:String = "player"):StageCharacterData
        return Reflect.field(stageData.characterData, charName);

    public function addObjects() {
        for (object in stageData.objects) {
            var sprite:FlxSprite = new FlxSprite(object.position[0], object.position[1]);
            if (object.animated) {
                sprite.frames = Paths.getSparrowAtlas(object.imagePath, stageData.imagePath);
                for (animation in object.animations) {
                    sprite.animation.addByPrefix(animation.prefix, animation.postfix, animation.fps, animation.looped);
                }

                sprite.animation.play(object.animations[0].prefix);
            } else
                sprite.loadGraphic(Paths.image(object.imagePath, stageData.imagePath));
            if (object.screenCenter) sprite.screenCenter();
            sprite.scale.set(object.scale[0], object.scale[1]);
            sprite.scrollFactor.set(object.scrollFactor[0], object.scrollFactor[1]);
            if (object.updateHitbox) sprite.updateHitbox();
            sprite.antialiasing = object.antialiasing;
            if (object.alpha != null) sprite.alpha = object.alpha;
            if (object.visible != null) sprite.visible = object.visible;
            stageObjects.set(object.name, sprite);
            container.insert(object.zIndex, sprite);

            for (script in stageScripts)
                script.set(object.name, sprite);
        }
    }
}

typedef StageData = {
    zoom:Float,
    imagePath:String,
    characterData:Dynamic,
    objects:Array<ObjectData>
}

typedef StageCharacterData = {
    position:Array<Float>,
    cameraOffset:Array<Float>
}

typedef ObjectData = {
    name:String,
    imagePath:String,
    animated:Bool,
    animations:Array<Character.AnimationData>,
    position:Array<Float>,
    scale:Array<Float>,
    scrollFactor:Array<Float>,
    updateHitbox:Bool,
    antialiasing:Bool,
    zIndex:Int,
    ?alpha:Float,
    ?visible:Bool,
    ?screenCenter:Bool
}