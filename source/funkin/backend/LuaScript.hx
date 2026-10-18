#if cpp
package funkin.backend;

import haxe.io.Bytes;
import llua.Convert;
import llua.Lua;
import llua.LuaException;
import llua.LuaL;
import llua.Lua.Lua_helper;
import llua.State;

class LuaScript
{
    private static var nextCallbackId:Int = 0;

    private var lua:State;
    private var parent:Dynamic;
    private var parentFields:Map<String, Bool> = [];
    private var getCallbackName:String;
    private var setCallbackName:String;
    private var closed:Bool = false;

    public function new(scriptPath:String, parent:Dynamic)
    {
        this.parent = parent;
        getCallbackName = '__haxeGet${nextCallbackId}';
        setCallbackName = '__haxeSet${nextCallbackId}';
        nextCallbackId++;

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
        Lua_helper.add_callback(lua, getCallbackName, getParentField);
        Lua_helper.add_callback(lua, setCallbackName, setParentField);

        try
        {
            var source:String = Paths.fileData(scriptPath);
            if (source == null)
                throw 'Lua script not found: $scriptPath';

            execute('get = function(name) return $getCallbackName(name) end\n'
                + 'set = function(name, value) return $setCallbackName(name, value) end\n'
                + source, scriptPath);
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
        Lua_helper.remove_callback(lua, getCallbackName);
        Lua_helper.remove_callback(lua, setCallbackName);
        Lua.close(lua);
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
            case Type.ValueType.TNull | Type.ValueType.TBool | Type.ValueType.TInt | Type.ValueType.TFloat | Type.ValueType.TClass(String):
                return value;
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

        var current:Dynamic = Reflect.getProperty(target, fieldName);
        switch (Type.typeof(current))
        {
            case Type.ValueType.TBool:
                if (Type.typeof(value) != Type.ValueType.TBool)
                    throw 'Game field "$field" requires a boolean.';
            case Type.ValueType.TInt:
                if (Type.typeof(value) != Type.ValueType.TInt && Type.typeof(value) != Type.ValueType.TFloat)
                    throw 'Game field "$field" requires a number.';
                value = Std.int(value);
            case Type.ValueType.TFloat:
                if (Type.typeof(value) != Type.ValueType.TInt && Type.typeof(value) != Type.ValueType.TFloat)
                    throw 'Game field "$field" requires a number.';
                value = value * 1.0;
            case Type.ValueType.TClass(String):
                if (!Std.isOfType(value, String))
                    throw 'Game field "$field" requires a string.';
            case Type.ValueType.TNull:
                switch (Type.typeof(value))
                {
                    case Type.ValueType.TNull | Type.ValueType.TBool | Type.ValueType.TInt | Type.ValueType.TFloat | Type.ValueType.TClass(String):
                    default:
                        throw 'Game field "$field" only supports simple Lua values.';
                }
            default:
                throw 'Game field "$field" is not a supported Lua value.';
        }

        Reflect.setProperty(target, fieldName, value);
        return value;
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
        var status:Int = LuaL.loadbuffer(lua, source, Bytes.ofString(source).length, chunkName);
        LuaException.ifErrorThrow(lua, status);
        LuaException.ifErrorThrow(lua, Lua.pcall(lua, 0, 0, 0));
    }
}
#end
