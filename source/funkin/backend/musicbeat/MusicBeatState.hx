package funkin.backend.musicbeat;

import flixel.FlxState;
#if cpp
import funkin.backend.LuaScript;
#end

/**
	* State That Handles Things For Conductor
	* Conductor Can Not Be Used Outside Of This State Unless You Are Manually Handling It Yourself.
	* TODO: Maybe Make Some Helper Functions In Conductor So You Can Just Do
	* ```haxe
	* var conductor:Conductor = new Conductor();
	* 
	* function update(elapsed:Float) {
	* 	conductor.update();
	* }
	* ```
 */
class MusicBeatState extends FlxState
{
	public var haxescripts:Array<HScript> = [];
	#if cpp
	public var luascripts:Array<LuaScript> = [];
	#end
	public var curBeat(get, never):Int;
	public var curStep(get, never):Int;

	private inline function get_curBeat():Int
	{
		return Conductor.curBeat;
	}

	private inline function get_curStep():Int
	{
		return Conductor.curStep;
	}

	override public function create()
	{
		var stateName = Type.getClassName(Type.getClass(FlxG.state)).split(".").pop();

		createHScript('states/$stateName');
		#if cpp
		createLuaScript('states/$stateName');
		#end
		super.create();
	}

	override public function destroy()
	{
		callScriptFunction("destroy");
		#if cpp
		for (script in luascripts)
			script.close();
		luascripts = [];
		#end
		super.destroy();
	}

	override public function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
		{
			Conductor.songPosition = FlxG.sound.music.time;
			Conductor.updateVisualPosition(Conductor.songPosition, elapsed, FlxG.sound.music.playing);
		}
		else
		{
			Conductor.songPosition = 0;
			Conductor.updateVisualPosition(0, elapsed, false);
		}

		var oldStep:Int = curStep;
		Conductor.update();

		if (oldStep != curStep && curStep >= 0)
			stepHit();

		super.update(elapsed);
	}

	public function stepHit():Void
	{
		if (Conductor.curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
	}

	/**
	 * Creates A HScript And Pushes It Too The HaxeScript Array
	 * @param scriptPath Path Too The Script
	 * @return HScript
	 */
	public function createHScript(scriptPath:String, autoCallCreate:Bool = true, autoPushTooScriptArray:Bool = true):Null<HScript> {
		var resolvedPath = HScript.resolvePath(scriptPath);

		if (resolvedPath == null)
			return null;

		try {
			var script:HScript = new HScript(resolvedPath, this);
			script.set("add", add);
			script.set("remove", remove);
			script.set("insert", insert);
			script.execute();
			script.syncParentFields();

			if (autoCallCreate && script.exists("create"))
				script.call("create");

			if (autoPushTooScriptArray)
				haxescripts.push(script);

			return script;
		} catch (e:Dynamic) {
			trace('Failed to load script "$resolvedPath": $e');
			return null;
		}
	}

	#if cpp
	public function createLuaScript(scriptPath:String, autoCallCreate:Bool = true):Null<LuaScript>
	{
		var resolvedPath:String = scriptPath;
		if (!Paths.exists(resolvedPath))
		{
			var luaPath:String = '$scriptPath.lua';
			if (Paths.exists(luaPath))
				resolvedPath = luaPath;
			else
				resolvedPath = null;
		}

		if (resolvedPath == null)
			return null;

		var script:LuaScript = new LuaScript(resolvedPath, this);
		luascripts.push(script);
		if (autoCallCreate)
			script.call("create");
		return script;
	}
	#end

	/**
	 * Calls A Function In Every Script Loaded
	 * @param func The Name Of The Function
	 * @param args Arguements Of The Function (Optional)
	 */
	public function callScriptFunction(func:String, ?args:Array<Dynamic>) {
		for (script in haxescripts)
		{
			script.syncParentFields();
			if (script.exists(func))
				script.call(func, args);
		}
		#if cpp
		for (script in luascripts)
			script.call(func, args);
		#end
	}
}
