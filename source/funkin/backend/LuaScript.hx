#if cpp
package funkin.backend;

import haxe.io.Bytes;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.Lua.Lua_helper;
import llua.Lua.Lua_Debug;
import llua.State;

class LuaScript {
    private static var nextCallbackId:Int = 0;

    private var lua:State;
    private var parent:Dynamic;
    private var parentFields:Map<String, Bool> = [];
    private var callbackNames:Array<String> = [];
    private var sprites:Map<String, FlxSprite> = [];
    private var objectReferences:Map<String, Dynamic> = [];
    private var nextObjectReference:Int = 0;
    private var closed:Bool = false;

    public function new(scriptPath:String, parent:Dynamic)
    {
        this.parent = parent;
        var callbackId:Int = nextCallbackId++;

        var parentClass:Class<Dynamic> = cast Type.getClass(parent);
        while (parentClass != null)
        {
            for (field in Type.getInstanceFields(parentClass))
            {
                if (!Reflect.isFunction(Reflect.field(parent, field)))
                    parentFields.set(field, true);
                else if (StringTools.startsWith(field, "get_"))
                    parentFields.set(field.substr(4), true);
            }
            parentClass = cast Type.getSuperClass(parentClass);
        }

        lua = LuaL.newstate();
        LuaL.openlibs(lua);

        @:privateAccess Lua.init_callbacks(lua);
        registerGlobalCallback("trace", luaTrace);
        registerGlobalCallback("print", luaTrace);
        registerGlobalCallback("get", getParentField);
        registerGlobalCallback("set", setParentField);
        registerGlobalCallback("callFunctionFromClass", callFunctionFromClass);
        registerGlobalCallback("makeSprite", makeSprite);
        registerGlobalCallback("getSprite", getSprite);
        registerGlobalCallback("setSprite", setSprite);

        try
        {
            var source:String = Paths.fileData(scriptPath);
            if (source == null)
                throw 'Lua script not found: $scriptPath';

            execute(source, scriptPath);
        }
        catch (error:Dynamic)
        {
            close();
            throw error;
        }
    }

    public function exists(functionName:String):Bool
    {
        Lua.getglobal(lua, functionName);
        var result:Bool = Lua.isfunction(lua, -1);
        Lua.pop(lua, 1);
        return result;
    }

    public function call(functionName:String, ?args:Array<Dynamic>):Void
    {
        if (exists(functionName))
            Convert.callLuaFuncNoReturns(lua, functionName, args);
    }

    public function get(field:String):Dynamic
    {
        return getParentField(field);
    }

    public function set(field:String, value:Dynamic):Void
    {
        setParentField(field, value);
    }

    public function close():Void
    {
        if (closed)
            return;

        closed = true;
        for (callbackName in callbackNames)
            Lua_helper.remove_callback(lua, callbackName);
        var state:FlxState = cast parent;
        for (sprite in sprites)
            state.remove(sprite, true);
        sprites.clear();
        objectReferences.clear();
        Lua.close(lua);
    }

    private function makeSprite(tag:String, x:Float, y:Float, imagePath:String):String
    {
        if (tag == "")
            throw "Sprite tag cannot be empty.";

        var state:FlxState = cast parent;
        if (sprites.exists(tag))
            state.remove(sprites.get(tag), true);

        var sprite:FlxSprite = new FlxSprite(x, y, Paths.image(imagePath));
        sprites.set(tag, sprite);
        state.add(sprite);
        return tag;
    }

    private function getSprite(path:String):Dynamic
    {
        var parts:Array<String> = parseFieldPath(path);
        if (parts.length < 2)
            throw 'Sprite path "$path" must include a tag and field, like "sprite.x".';

        var tag:String = parts.shift();
        var fieldName:String = parts.pop();
        var sprite:FlxSprite = requireSprite(tag);
        var target:Dynamic = resolveSpriteTarget(sprite, parts, path);
        if (!hasProperty(target, fieldName))
            throw 'Unknown sprite path "$path".';

        var value:Dynamic = Reflect.getProperty(target, fieldName);
        return switch (Type.typeof(value))
        {
            case Type.ValueType.TNull | Type.ValueType.TBool | Type.ValueType.TInt | Type.ValueType.TFloat | Type.ValueType.TClass(String):
                value;
            default:
                throw 'Sprite field in "$path" is not a supported Lua value.';
        }
    }

    private function setSprite(path:String, value:Dynamic):Dynamic
    {
        var parts:Array<String> = parseFieldPath(path);
        if (parts.length < 2)
            throw 'Sprite path "$path" must include a tag and field, like "sprite.x".';

        var tag:String = parts.shift();
        var fieldName:String = parts.pop();
        var sprite:FlxSprite = requireSprite(tag);
        var target:Dynamic = resolveSpriteTarget(sprite, parts, path);
        if (!hasProperty(target, fieldName))
            throw 'Unknown sprite path "$path".';

        value = resolveObjectReference(value);
        var current:Dynamic = Reflect.getProperty(target, fieldName);
        switch (Type.typeof(current))
        {
            case Type.ValueType.TBool:
                if (Type.typeof(value) != Type.ValueType.TBool)
                    throw 'Sprite field in "$path" requires a boolean.';
            case Type.ValueType.TInt:
                if (Type.typeof(value) != Type.ValueType.TInt && Type.typeof(value) != Type.ValueType.TFloat)
                    throw 'Sprite field in "$path" requires a number.';
                value = value % 1 == 0 ? Std.int(value) : value * 1.0;
            case Type.ValueType.TFloat:
                if (Type.typeof(value) != Type.ValueType.TInt && Type.typeof(value) != Type.ValueType.TFloat)
                    throw 'Sprite field in "$path" requires a number.';
                value = value * 1.0;
            case Type.ValueType.TClass(String):
                if (!Std.isOfType(value, String))
                    throw 'Sprite field in "$path" requires a string.';
            case Type.ValueType.TClass(_):
                if (value == null || Type.getClass(value) != Type.getClass(current))
                    throw 'Sprite field in "$path" requires a ${Type.getClassName(Type.getClass(current))}.';
            default:
                throw 'Sprite field in "$path" is not a supported Lua value.';
        }

        Reflect.setProperty(target, fieldName, value);
        return value;
    }

    private function requireSprite(tag:String):FlxSprite
    {
        var sprite:FlxSprite = sprites.get(tag);
        if (sprite == null)
            throw 'Unknown sprite tag "$tag".';
        return sprite;
    }

    private function createObjectReference(value:Dynamic):Dynamic
    {
        var reference:String = Std.string(nextObjectReference++);
        objectReferences.set(reference, value);
        return {__luaObjectReference: reference};
    }

    private function resolveObjectReference(value:Dynamic):Dynamic
    {
        if (value != null && Reflect.hasField(value, "__luaObjectReference"))
        {
            var reference:Dynamic = Reflect.field(value, "__luaObjectReference");
            if (Std.isOfType(reference, String) && objectReferences.exists(reference))
                return objectReferences.get(reference);
        }

        return value;
    }

    private function resolveSpriteTarget(sprite:FlxSprite, path:Array<String>, fullField:String):Dynamic
    {
        var target:Dynamic = sprite;
        for (fieldName in path)
        {
            if (!hasProperty(target, fieldName))
                throw 'Unknown sprite field "$fullField".';
            target = Reflect.getProperty(target, fieldName);
            if (target == null)
                throw 'Cannot access "$fullField" because an intermediate sprite field is null.';
        }
        return target;
    }

    private function getParentField(field:String):Dynamic
    {
        var path:Array<String> = parseFieldPath(field);
        var fieldName:String = path.pop();
        var target:Dynamic = resolveFieldTarget(path, fieldName, field);
        if (!hasProperty(target, fieldName))
            throw 'Unknown game field "$field".';

        var value:Dynamic = Reflect.getProperty(target, fieldName);
        switch (Type.typeof(value))
        {
            case Type.ValueType.TNull | Type.ValueType.TBool | Type.ValueType.TInt | Type.ValueType.TFloat | Type.ValueType.TClass(String)
                | Type.ValueType.TObject | Type.ValueType.TClass(Array) | Type.ValueType.TClass(haxe.ds.StringMap)
                | Type.ValueType.TClass(haxe.ds.ObjectMap):
                return value;
            case Type.ValueType.TClass(_):
                return createObjectReference(value);
            default:
                throw 'Game field "$field" is not a supported Lua value.';
        }
    }

    private function setParentField(field:String, value:Dynamic):Dynamic
    {
        var path:Array<String> = parseFieldPath(field);
        var fieldName:String = path.pop();
        var target:Dynamic = resolveFieldTarget(path, fieldName, field);
        if (!hasProperty(target, fieldName))
            throw 'Unknown game field "$field".';

        value = resolveObjectReference(value);
        var current:Dynamic = Reflect.getProperty(target, fieldName);
        switch (Type.typeof(current))
        {
            case Type.ValueType.TBool:
                if (Type.typeof(value) != Type.ValueType.TBool)
                    throw 'Game field "$field" requires a boolean.';
            case Type.ValueType.TInt:
                if (Type.typeof(value) != Type.ValueType.TInt && Type.typeof(value) != Type.ValueType.TFloat)
                    throw 'Game field "$field" requires a number.';
                if (value % 1 == 0)
                    value = Std.int(value);
                else
                    value = value * 1.0;
            case Type.ValueType.TFloat:
                if (Type.typeof(value) != Type.ValueType.TInt && Type.typeof(value) != Type.ValueType.TFloat)
                    throw 'Game field "$field" requires a number.';
                value = value * 1.0;
            case Type.ValueType.TClass(String):
                if (!Std.isOfType(value, String))
                    throw 'Game field "$field" requires a string.';
            case Type.ValueType.TClass(Array):
                if (Std.isOfType(value, Array))
                {
                    value = cast(value, Array<Dynamic>);
                }
                else if (Type.typeof(value) == Type.ValueType.TObject && Reflect.fields(value).length == 0)
                {
                    value = [];
                }
                else
                {
                    throw 'Game field "$field" requires a Lua array.';
                }
            case Type.ValueType.TClass(_):
                if (value == null || Type.getClass(value) != Type.getClass(current))
                    throw 'Game field "$field" requires a ${Type.getClassName(Type.getClass(current))}.';
            case Type.ValueType.TNull:
                switch (Type.typeof(value))
                {
                    case Type.ValueType.TNull | Type.ValueType.TBool | Type.ValueType.TInt | Type.ValueType.TFloat | Type.ValueType.TClass(String)
                        | Type.ValueType.TObject | Type.ValueType.TClass(Array) | Type.ValueType.TClass(haxe.ds.StringMap)
                        | Type.ValueType.TClass(haxe.ds.ObjectMap):
                    default:
                        throw 'Game field "$field" only supports simple Lua values.';
                }
            default:
                throw 'Game field "$field" is not a supported Lua value.';
        }

        Reflect.setProperty(target, fieldName, value);
        return value;
    }

    private function luaTrace(?message:Dynamic):Void
    {
        var info:Lua_Debug = {};
        var source:String = "unknown";
        var line:Int = 0;

        if (Lua.getstack(lua, 1, info) != 0 && Lua.getinfo(lua, "Sl", info) != 0)
        {
            if (info.source != null)
                source = info.source.startsWith("@") ? info.source.substr(1) : info.source;
            if (info.currentline != null)
                line = info.currentline;
        }

        var messages:Array<String> = [];
        for (index in 1...(Lua.gettop(lua) + 1))
            messages.push(Std.string(Convert.fromLua(lua, index)));

        Sys.println('$source:$line: ${messages.join("\t")}');
    }

    private function registerGlobalCallback(globalName:String, callback:Dynamic):Void
    {
        var name:String = 'callback_${nextCallbackId++}';
        Lua_helper.add_callback(lua, name, callback);
        callbackNames.push(name);
        Lua.getglobal(lua, name);
        Lua.setglobal(lua, globalName);
    }

    private function callFunctionFromClass(functionPath:String, ?params:Array<Dynamic>):Dynamic
    {
        var path:Array<String> = parseFieldPath(functionPath);
        if (path.length < 2)
            throw 'Expected a class and function name, got "$functionPath".';

        var className:String = path.shift();
        var classRef:Class<Dynamic> = cast HScript.defaultImports.get(className);
        if (classRef == null)
            classRef = Type.resolveClass(className);

        if (classRef == null)
            throw 'Unknown class "$className".';

        var target:Dynamic = classRef;
        while (path.length > 1)
        {
            var field:String = path.shift();
            if (!hasProperty(target, field))
                throw 'Unknown field "$field" in "$functionPath".';
            target = Reflect.getProperty(target, field);
            if (target == null)
                throw 'Cannot access "$functionPath" because "$field" is null.';
        }

        var functionName:String = path[0];
        var method:Dynamic = Reflect.field(target, functionName);
        if (!Reflect.isFunction(method))
            throw 'Unknown function "$functionPath".';

        var resolvedParams:Array<Dynamic> = params == null ? [] : params.map(resolveObjectReference);
        return Reflect.callMethod(target, method, resolvedParams);
    }

    private function parseFieldPath(field:String):Array<String>
    {
        var path:Array<String> = field.split(".");
        for (fieldName in path)
        {
            if (fieldName == "")
                throw 'Invalid game field "$field".';
        }
        return path;
    }

    private function resolveFieldTarget(path:Array<String>, fieldName:String, fullField:String):Dynamic
    {
        if (path.length == 0)
        {
            if (!parentFields.exists(fieldName))
                throw 'Unknown game field "$fullField".';
            return parent;
        }

        var rootField:String = path.shift();
        if (!parentFields.exists(rootField))
            throw 'Unknown game field "$fullField".';

        var target:Dynamic = Reflect.getProperty(parent, rootField);
        for (fieldName in path)
        {
            if (target == null || !hasProperty(target, fieldName))
                throw 'Unknown game field "$fullField".';

            target = Reflect.getProperty(target, fieldName);
        }

        if (target == null)
            throw 'Cannot access "$fullField" because an intermediate game field is null.';

        return target;
    }

    private function hasProperty(target:Dynamic, field:String):Bool
    {
        if (Reflect.hasField(target, field))
            return true;

        var targetClass:Class<Dynamic> = cast Type.getClass(target);
        while (targetClass != null)
        {
            for (instanceField in Type.getInstanceFields(targetClass))
            {
                if (instanceField == field || instanceField == 'get_$field' || instanceField == 'set_$field')
                    return true;
            }
            targetClass = cast Type.getSuperClass(targetClass);
        }

        return false;
    }

    private function execute(source:String, chunkName:String):Void
    {
        var sourceName:String = chunkName.startsWith("@") ? chunkName : '@$chunkName';
        var status:Int = LuaL.loadbuffer(lua, source, Bytes.ofString(source).length, sourceName);
        if (status != Lua.LUA_OK)
            throw 'Lua compile error in "$chunkName": ${Lua.tostring(lua, -1)}';

        status = Lua.pcall(lua, 0, 0, 0);
        if (status != Lua.LUA_OK)
            throw 'Lua runtime error in "$chunkName": ${Lua.tostring(lua, -1)}';
    }
}
#end
