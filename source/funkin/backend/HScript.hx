package funkin.backend;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;

class HScript extends Iris {
    private var parent:Dynamic;
    private var parentFields:Array<String> = [];
    private var parentValues:Map<String, Dynamic> = [];

    public static var supportedFileTypes:Array<String> = ["hx", "hxs", "hxc"];
    public static var defaultImports:Map<String, Dynamic> = [
        "FlxG" => FlxG,
        "FlxSprite" => FlxSprite,
        "Paths" => Paths,

        //Utils
        "CoolUtil" => funkin.backend.util.CoolUtil,

        // Game Stuff
        "PlayState" => funkin.states.game.PlayState,
        "Character" => funkin.states.game.objects.Character,
        "Note" => funkin.states.game.objects.Note,
        "StrumLine" => funkin.states.game.objects.StrumLine,
        "Strum" => funkin.states.game.objects.Strum,
        "Song" => Song,
        "Conductor" => Conductor,

        //Misc
        "CustomShader" => funkin.shaders.CustomShader
    ];

    public static function resolvePath(scriptPath:String):Null<String> {
        if (Paths.exists(scriptPath))
            return scriptPath;

        for (fileType in supportedFileTypes)
            if (Paths.exists('$scriptPath.$fileType'))
                return '$scriptPath.$fileType';

        return null;
    }

    override public function new(scriptPath:String, parent:Dynamic) {
        var resolvedPath = resolvePath(scriptPath);
        if (resolvedPath == null)
            throw 'HScript file not found: $scriptPath';

        super(Paths.fileData(resolvedPath), new IrisConfig(resolvedPath, false));
        this.parent = parent;

        for (thing in defaultImports.keys())
            set(thing, defaultImports.get(thing));

        var parentClass:Class<Dynamic> = cast Type.getClass(parent);
        while (parentClass != null)
        {
            for (field in Type.getInstanceFields(parentClass))
            {
                var value = Reflect.field(parent, field);
                if (!exists(field) && !Reflect.isFunction(value))
                {
                    set(field, value);
                    parentFields.push(field);
                    parentValues.set(field, value);
                }
            }

            parentClass = cast Type.getSuperClass(parentClass);
        }
    }

    override public function call(fun:String, ?args:Array<Dynamic>)
        if (exists(fun))
            return super.call(fun, args);
        else
            return null;

    public function syncParentFields():Void {
        for (field in parentFields)
        {
            if (get(field) == parentValues.get(field))
            {
                var value = Reflect.field(parent, field);
                if (!Reflect.isFunction(value))
                {
                    set(field, value);
                    parentValues.set(field, value);
                }
            }
        }
    }
}