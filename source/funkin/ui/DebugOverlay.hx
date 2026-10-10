// OG Class made by SwordCube, just edited it too make it work
// https://git.gay/AnimusTeam/gbPsych/src/branch/develop/source/funkin/backend/DebugOverlay.hx
package funkin.ui;

import sys.io.Process;
import flixel.FlxState;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.util.FlxSignal;
import funkin.backend.util.MemoryUtil;
import lime.system.System;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;

enum abstract DebugStatDisplayMode(Int) from Int to Int
{
	final NONE = 0;
	final DEFAULT = 1;
	final BASIC = 2;
	final ALL = 3;
}

class DebugStats extends Sprite
{
	public var boxWidth:Float = 0;
	public var boxHeight:Float = 0;

	public var shape:Shape;
	public var metricsContainer:Sprite;

	public function new()
	{
		super();

		shape = new Shape();
		addChild(shape);

		metricsContainer = new Sprite();
		metricsContainer.x = 8;
		metricsContainer.y = 3;
		addChild(metricsContainer);
	}

	public function addMetric(metric:DebugMetric):Void
	{
		var h:Float = 0;
		for (i in 0...metricsContainer.numChildren)
		{
			final m:DebugMetric = cast metricsContainer.getChildAt(i);
			h += m.getMetricHeight();
		}
		metric.y += h;
		metricsContainer.addChild(metric);
		__enterFrame(0);
	}

	public function addSeparator():Void
	{
		addMetric(new Separator());
	}

	override function __enterFrame(_:Float):Void
	{
		super.__enterFrame(_);

		if (!visible)
			return;

		var contentY:Float = 0;
		var contentWidth:Float = 0;

		for (i in 0...metricsContainer.numChildren)
		{
			var metric:DebugMetric = cast metricsContainer.getChildAt(i);

			if (!metric.visible)
				continue;

			metric.y = contentY;
			contentY += metric.getMetricHeight();
			contentWidth = Math.max(contentWidth, metric.width);
		}

		final prevBoxWidth:Float = boxWidth;
		final prevBoxHeight:Float = boxHeight;

		boxWidth = contentWidth + 18;
		boxHeight = contentY + 10;

		if (prevBoxWidth == boxWidth && prevBoxHeight == boxHeight)
			return;

		shape.graphics.clear();

		shape.graphics.beginFill(0x282A30, 0.8);
		shape.graphics.drawRoundRect(0, 0, boxWidth, boxHeight, 20, 20);
		shape.graphics.endFill();

		shape.graphics.lineStyle(1, 0x696E7E, 0.8);
		shape.graphics.drawRoundRect(0, 0, boxWidth, boxHeight, 20, 20);
		shape.graphics.endFill();
	}
}

class DebugMetric extends Sprite
{
	public function getMetricHeight():Float
	{
		return 0;
	}

	override function get_height()
	{
		height = getMetricHeight(); // lol
		return super.get_height();
	}
}

class Separator extends DebugMetric
{
	public var shape:Shape;
	public var lineWidth:Float = 0;

	public function new()
	{
		super();

		shape = new Shape();
		addChild(shape);
	}

	override function __enterFrame(_:Float):Void
	{
		super.__enterFrame(_);

		if (parent?.parent?.parent?.parent != null && !cast(parent.parent.parent.parent, DebugOverlay).visible)
			return;

		final prevLineWidth:Float = lineWidth;
		lineWidth = cast(parent.parent, DebugStats).boxWidth - 22;

		// don't redraw the line if it's size hasn't changed
		if (prevLineWidth == lineWidth)
			return;

		shape.graphics.clear();

		if (lineWidth > 0)
		{
			shape.graphics.lineStyle(1, 0x696E7E, 0.8);
			shape.graphics.moveTo(4, 13);
			shape.graphics.lineTo(lineWidth, 13);
			shape.graphics.endFill();
		}
	}

	override function getMetricHeight():Float
	{
		return 20;
	}
}

class TextMetric extends DebugMetric
{
	public var boldText:TextField;
	public var normalText:TextField;
	public var additionalText:TextField;

	public var updateNormalText:Void->String;
	public var updateAdditionalText:Void->String;

	public function new(boldText:String, normalText:Void->String, ?additionalText:Void->String = null)
	{
		super();
		this.updateNormalText = normalText;
		this.updateAdditionalText = additionalText;

		this.boldText = new TextField();
		this.boldText.defaultTextFormat = new TextFormat(Paths.font('jetbrains-mono/bold'), 14, 0xFFFFFF);
		this.boldText.autoSize = LEFT;
		this.boldText.text = boldText ?? "";
		this.boldText.wordWrap = false;
		this.boldText.mouseEnabled = false;
		this.boldText.selectable = false;
		this.boldText.embedFonts = true;
		addChild(this.boldText);

		this.normalText = new TextField();
		this.normalText.defaultTextFormat = new TextFormat(Paths.font('jetbrains-mono/regular'), 14, 0xFFFFFF);
		this.normalText.autoSize = LEFT;
		this.normalText.text = normalText();
		this.normalText.x = this.boldText.x + ((this.boldText.text != "") ? (this.boldText.width - 2) : 0);
		this.normalText.wordWrap = false;
		this.normalText.mouseEnabled = false;
		this.normalText.selectable = false;
		this.normalText.embedFonts = true;
		addChild(this.normalText);

		if (additionalText != null)
		{
			this.additionalText = new TextField();
			this.additionalText.defaultTextFormat = new TextFormat(Paths.font('jetbrains-mono/regular'), 14, 0xFFFFFF);
			this.additionalText.autoSize = LEFT;
			this.additionalText.text = additionalText();
			this.additionalText.alpha = 0.45;
			this.additionalText.x = this.normalText.x + (this.normalText.width - 2);
			this.additionalText.wordWrap = false;
			this.additionalText.mouseEnabled = false;
			this.additionalText.selectable = false;
			this.additionalText.embedFonts = true;
			addChild(this.additionalText);
		}
		_updateText();
	}

	override function getMetricHeight():Float
	{
		final textField:TextField = (this.boldText.text != "") ? this.boldText : this.normalText;
		return textField.height - 8;
	}

	override function __enterFrame(dt:Float):Void
	{
		super.__enterFrame(dt);

		if (parent?.parent?.parent?.parent != null && !cast(parent.parent.parent.parent, DebugOverlay).visible)
			return;

		_updateText();
	}

	private function _updateText():Void
	{
		if (this.updateNormalText != null)
		{
			final newText:String = this.updateNormalText();
			if (this.normalText.text != newText)
				this.normalText.text = newText;
		}
		if (this.updateAdditionalText != null)
		{
			final newText:String = this.updateAdditionalText();
			if (this.additionalText.text != newText)
				this.additionalText.text = newText;
		}
		this.normalText.x = this.boldText.x + (this.boldText.width - 2);

		if (this.additionalText != null)
			this.additionalText.x = this.normalText.x + (this.normalText.width - 2);
	}
}

class StaticTextMetric extends TextMetric
{
	public function new(boldText:String, normalText:Void->String, ?additionalText:Void->String = null)
	{
		super(boldText, normalText, additionalText);
		this.updateNormalText = null;
		this.updateAdditionalText = null;
	}
}

class GraphMetric extends DebugMetric
{
	public var graphWidth:Int = 0;
	public var graphHeight:Int = 0;

	public var delay:Float = 0.05;
	public var data:Array<Float> = [];

	public var textField:TextField;
	public var onUpdate:GraphMetric->Float->Void;

	public var shape:Shape;

	private var _max:Float = 0;
	private var _time:Float = 0;

	private var _systemTimestamp:Float = 0;
	private var _shouldUpdate:Bool = true;

	public function new(text:String, width:Int, height:Int, onUpdate:GraphMetric->Float->Void)
	{
		super();
		this.graphWidth = width;
		this.graphHeight = height;
		this.onUpdate = onUpdate;

		textField = new TextField();
		textField.defaultTextFormat = new TextFormat(Paths.font('jetbrains-mono/regular'), false, 10, 0xFFFFFF);
		textField.autoSize = LEFT;
		textField.text = text;
		textField.wordWrap = false;
		textField.mouseEnabled = false;
		textField.selectable = false;
		textField.embedFonts = true;
		addChild(textField);

		shape = new Shape();
		addChild(shape);

		data.resize(Std.int(width / 2));
		for (i in 0...data.length)
			data.unsafeSet(i, 0);

		__enterFrame(0);
	}

	override function getMetricHeight():Float
	{
		return graphHeight + 25;
	}

	public function update(dt:Float, val:Float)
	{
		final lastTime:Float = _time;
		_time = (_time + dt) % delay;

		if (dt > delay || lastTime > _time)
		{
			data.push(val);
			data.shift();

			var max:Float = 0;
			for (i in 0...data.length)
			{
				final v:Float = data.unsafeGet(i);
				if (v > max)
					max = v;
			}
			_max = max;
			_shouldUpdate = true;
		}
	}

	public inline function getAverage():Float
	{
		return data.getAverage();
	}

	override function __enterFrame(_:Float)
	{
		final now:Float = System.getTimer();

		final dt:Float = now - _systemTimestamp;
		_systemTimestamp = now;

		super.__enterFrame(dt);

		if (onUpdate != null)
			onUpdate(this, dt);

		if (!_shouldUpdate)
			return;

		final statsVisible:Bool = parent?.parent?.parent?.parent != null && cast(parent.parent.parent.parent, DebugOverlay).visible;
		if (statsVisible)
		{
			shape.graphics.clear();

			// draw a transparent bg just to make padding
			// TODO: i need to find a better way to do this bro
			shape.graphics.beginFill(0x696E7E, 0);
			shape.graphics.drawRect(0, 20, graphWidth, graphHeight + 5);
			shape.graphics.endFill();

			shape.graphics.lineStyle(1, 0xFFFFFF);

			final max:Float = (Math.ceil(_max / 10) * 10) + 20;
			final steps:Float = graphWidth / data.length;

			for (i in 0...data.length)
			{
				final x:Float = (steps * i) + 4;
				final y:Float = (graphHeight * (-data.unsafeGet(i) / max + 1)) + 20;

				if (i == 0)
					shape.graphics.moveTo(x, y);

				shape.graphics.lineTo(x, y);
			}
			shape.graphics.endFill();
		}
		_shouldUpdate = true;
	}
}

class DebugOverlay extends Sprite
{
	public var displayMode:DebugStatDisplayMode = DEFAULT;
	public var visibilityChanged:FlxTypedSignal<Bool->Void> = new FlxTypedSignal<Bool->Void>();
	public var statsContainer:Sprite;

	public function addStats(stats:DebugStats):Void
	{
		if (statsContainer.numChildren > 0)
			stats.y += statsContainer.height + 10;

		statsContainer.addChild(stats);
		stats.__enterFrame(0);
	}

	public var currentFPS:Int = 0;

	public function getVRAM():Float
	{
		// use rough estimate
		var amount:Float = 0;
		@:privateAccess
		for (graph in FlxG.bitmap._cache)
		{
			if (graph.bitmap.__texture != null)
				amount += graph.bitmap.width * graph.bitmap.height * 4;
		}
		return amount;
	}

	public function getPeakVRAM():Float
	{
		final vram:Float = getVRAM();
		if (vram > _peakVRAM)
			_peakVRAM = vram;
		return _peakVRAM;
	}

	public function cleanGPUName(name:String):String
	{
		if (name == null || name.trim() == "")
			return "N/A";

		name = ~/(\s*\(.*?\))/g.replace(name, ""); // remove parentheses and contents
		name = ~/(\/[\w\s_\-\.]+)/g.replace(name, ""); // remove slashes and things like "/PCIe/SSE2"
		name = ~/\(TM\)|\(R\)/g.replace(name, ""); // remove (TM), (R), etc.
		name = ~/Graphics\s*$/gi.replace(name, ""); // remove redundant "Graphics" at the end

		return name.trim();
	}

	public function new()
	{
		super();

		statsContainer = new Sprite();
		statsContainer.x = statsContainer.y = 15;
		addChild(statsContainer);

		final mainStats:DebugStats = new DebugStats();
        mainStats.addMetric(new TextMetric("FPS Info", () -> return ""));
        mainStats.addSeparator();
		mainStats.addMetric(new TextMetric("FPS: ", () -> return Std.string((FlxG.drawFramerate > 0) ? Math.min(currentFPS, FlxG.drawFramerate) : currentFPS)));
		mainStats.addMetric(new TextMetric("GC MEM: ", () -> return CoolUtil.formatBytes(_mem), () -> return ' / ${CoolUtil.formatBytes(_peakMem)}'));
		mainStats.addMetric(new TextMetric("TASK MEM: ", () -> return CoolUtil.formatBytes(_appMem), () -> return ' / ${CoolUtil.formatBytes(_peakAppMem)}'));
		mainStats.addMetric(new TextMetric("VRAM: ", () -> return CoolUtil.formatBytes(getVRAM()), () -> return ' / ${CoolUtil.formatBytes(getPeakVRAM())}'));
		#if FLX_TRACK_PERFORMANCE
		mainStats.addMetric(new TextMetric("DRAW CALLS: ", () -> return Std.string(FlxBasic.visibleCount)));
		mainStats.addMetric(new TextMetric("BATCHED DRAW CALLS: ", () -> return Std.string(FlxDrawBaseItem.drawCalls)));
		#end
		mainStats.addMetric(new StaticTextMetric("API: ", () ->
		{
			// TODO: whenever OpenFL gets support for more than OpenGL, detect the API properly
			@:privateAccess
			final gl = FlxG.stage.context3D.gl;
			final fullFuckingLegalName:String = Std.string(gl.getParameter(gl.VERSION)); // outputs smth like OpenGL ES 3.2 Mesa 25.1.9, we need to filter it to just the 3.2 part, that's the GL version

			final versionMatch:EReg = ~/(\d+\.\d+)/;
			final cleanVersion:String = versionMatch.match(fullFuckingLegalName) ? versionMatch.matched(0) : "N/A";

			return 'OpenGL ${cleanVersion}';
		}));
		mainStats.addSeparator();
		mainStats.addMetric(new GraphMetric("Frametime (0ms avg)", 300, 40, (graph:GraphMetric, dt:Float) ->
		{
			graph.update(dt * 0.001, dt);
			graph.textField.textColor = 0xFFFFFF;
			graph.textField.text = 'Frametime (${FlxMath.roundDecimal(graph.getAverage(), 4)}ms avg)';
		}));
		addStats(mainStats);

		final conductorStats = new DebugStats();
        conductorStats.addMetric(new TextMetric("Conductor Info", () -> return ""));
        conductorStats.addSeparator();
		conductorStats.addMetric(new TextMetric("Current Song Position: ", () -> return Std.string(FlxMath.roundDecimal(_getSongPos(), 3))));
		conductorStats.addMetric(new TextMetric("", () ->
		{
			final step:Int = _getCurStep();
			return '- ${step} step${(step != 1) ? 's' : ''}';
		}));
		conductorStats.addMetric(new TextMetric("", () ->
		{
			final beat:Int = _getCurBeat();
			return '- ${beat} beat${(beat != 1) ? 's' : ''}';
		}));
		conductorStats.addMetric(new TextMetric("", () ->
		{
			final measure:Int = _getCurMeasure();
			return '- ${measure} measure${(measure != 1) ? 's' : ''}';
		}));
		conductorStats.addSeparator();
		conductorStats.addMetric(new TextMetric("Current BPM: ", () -> return Std.string(_getBPM())));
		conductorStats.addMetric(new TextMetric("Time Signature: ", () -> return Std.string(_getTimeSignature())));
		addStats(conductorStats);

		final flixelStats = new DebugStats();
        flixelStats.addMetric(new TextMetric("Flixel Info", () -> return ""));
        flixelStats.addSeparator();
		flixelStats.addMetric(new TextMetric("State: ", () -> return Type.getClassName(Type.getClass(FlxG.state))));
		flixelStats.addMetric(new TextMetric("Objects: ", () ->
		{
			var count:Int = 0;

			var state:FlxState = FlxG.state;
			state.forEach((_) -> count++, true);

			while (state.subState != null)
			{
				state = state.subState;
				state.forEach((_) -> count++, true);
			}
			return Std.string(count);
		}));
		flixelStats.addMetric(new TextMetric("Graphics: ", () ->
		{
			var count:Int = 0;

			@:privateAccess
			for (_ in FlxG.bitmap._cache)
				count++;

			return Std.string(count);
		}));
		flixelStats.addMetric(new TextMetric("Sounds: ", () -> return Std.string(FlxG.sound.list.length)));
		addStats(flixelStats);

		final systemStats = new DebugStats();
        systemStats.addMetric(new TextMetric("System Info", () -> return ""));
        systemStats.addSeparator();
		systemStats.addMetric(new StaticTextMetric("GPU: ", () ->
		{
			@:privateAccess
			final gl = FlxG.stage.context3D.gl;
			final fullFuckingLegalName:String = Std.string(gl.getParameter(gl.RENDERER));

			return cleanGPUName(fullFuckingLegalName);
		}));
		systemStats.addMetric(new StaticTextMetric("CPU: ", () ->
		{
			@:privateAccess
			var proc = new Process("wmic", ["cpu", "get", "Name"]);
			proc.stdout.readLine();
			var output = proc.stdout.readLine();
			if (output != null)
				output = StringTools.trim(output);
			else
				output = "Unknown";
			return output;
		}));
		systemStats.addMetric(new StaticTextMetric("OS: ", () ->
		{
			@:privateAccess
			switch (Sys.systemName())
			{
				case "Windows":
					try
					{
						var proc = new Process("reg", [
							"query",
							"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
							"/v",
							"ProductName"
						]);
						var output = proc.stdout.readAll().toString();
						proc.close();

						var lines = output.split("\n");
						for (line in lines)
						{
							if (line.indexOf("ProductName") != -1)
							{
								var parts = line.split("REG_SZ");
								if (parts.length > 1)
								{
									return StringTools.trim(parts[1]);
								}
							}
						}
					}
					catch (e:Dynamic) {}
					return "Windows (Exact edition unknown)";

				case "Mac":
					try
					{
						var proc = new Process("sw_vers", ["-productName"]);
						var name = StringTools.trim(proc.stdout.readAll().toString());

						var procVer = new Process("sw_vers", ["-productVersion"]);
						var ver = StringTools.trim(procVer.stdout.readAll().toString());

						proc.close();
						procVer.close();
						return name + " " + ver;
					}
					catch (e:Dynamic) {}
					return "macOS";

				case "Linux":
					if (sys.FileSystem.exists("/etc/os-release"))
					{
						var content = sys.io.File.getContent("/etc/os-release");
						for (line in content.split("\n"))
						{
							if (line.indexOf("PRETTY_NAME=") == 0)
							{
								var name = line.split("=")[1];
								return StringTools.trim(name.replace('"', ''));
							}
						}
					}
					return "Linux";

				default:
					return Sys.systemName();
			}
		}));
		addStats(systemStats);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, (e:KeyboardEvent) ->
		{
			if (e.keyCode == FlxKey.F3)
			{
				final prevDisplayMode:Int = cast displayMode;
				displayMode = cast((prevDisplayMode + 1) % 4);
				updateDisplayMode();
			}
		});
		alpha = 0;
		__enterFrame(0);
	}

	public function updateDisplayMode():Void
	{
		visible = (displayMode != NONE);
		visibilityChanged.dispatch(visible);

		switch (displayMode)
		{
			case NONE: // nothing lol

			case DEFAULT:
				for (i in 0...statsContainer.numChildren)
				{
					var stats:DebugStats = cast statsContainer.getChildAt(i);
					stats.visible = i < 1;

					if (stats.visible)
					{
						for (j in 0...stats.metricsContainer.numChildren)
						{
							var metric:DebugMetric = cast stats.metricsContainer.getChildAt(j);
							metric.visible = !Std.isOfType(metric, GraphMetric);
						}
					}
				}

			case BASIC:
				for (i in 0...statsContainer.numChildren)
				{
					var stats:DebugStats = cast statsContainer.getChildAt(i);
					stats.visible = i < 1;

					if (stats.visible)
					{
						for (j in 0...stats.metricsContainer.numChildren)
						{
							var metric:DebugMetric = cast stats.metricsContainer.getChildAt(j);
							metric.visible = true;
						}
					}
				}

			case ALL:
				for (i in 0...statsContainer.numChildren)
				{
					var stats:DebugStats = cast statsContainer.getChildAt(i);
					stats.visible = true;

					for (j in 0...stats.metricsContainer.numChildren)
					{
						var metric:DebugMetric = cast stats.metricsContainer.getChildAt(j);
						metric.visible = true;
					}
				}
		}

		for (i in 0...statsContainer.numChildren)
		{
			var stats:DebugStats = cast statsContainer.getChildAt(i);
			var contentY:Float = 0;

			for (j in 0...stats.metricsContainer.numChildren)
			{
				var metric:DebugMetric = cast stats.metricsContainer.getChildAt(j);

				if (metric.visible)
				{
					metric.y = contentY;
					contentY += metric.getMetricHeight();
				}
			}

			stats.__enterFrame(0);
		}
	}

	override function __enterFrame(_):Void
	{
		final now:Float = System.getTimer();
		final dt:Float = now - _timestamp;

		_frames++;
		_fpsTimer += dt;

		while (_fpsTimer >= 1000)
		{
			currentFPS = _frames;
			_frames = 0;
			_fpsTimer -= 1000;

			_mem = MemoryUtil.currentMemUsage();
			_peakMem = MemoryUtil.peakMemUsage();

			_appMem = MemoryUtil.currentAppMemUsage();
			_peakAppMem = MemoryUtil.peakAppMemUsage();

			if (visible)
				MemoryUtil.clearMinor(); // do GC otherwise text make memory go boom
		}
		_timestamp = now;

		super.__enterFrame(dt);

		if (!_firstFramePassed)
		{
			_firstFramePassed = true;

			displayMode = (visible) ? DEFAULT : NONE;
			updateDisplayMode();

			alpha = 1;
		}
	}

	private var _firstFramePassed:Bool = false;

	private var _frames:Int = 0;
	private var _fpsTimer:Float = 0;
	private var _timestamp:Float = 0;

	private var _mem:Float = 0;
	private var _peakMem:Float = 0;

	private var _appMem:Float = 0;
	private var _peakAppMem:Float = 0;

	private var _peakVRAM:Float = 0;

	// TODO: make these work for this engine lol
	private function _getCurStep():Int @:privateAccess {
		return Conductor.curStep;
	}

	private inline function _getCurBeat():Int @:privateAccess {
		return Conductor.curBeat;
	}

	private inline function _getCurMeasure():Int @:privateAccess {
		return 0;
	}

	private inline function _getSongPos():Float
	{
		return Conductor.songPosition;
	}

	private inline function _getBPM():Float
	{
		return Conductor.bpm;
	}

	private inline function _getTimeSignature():String
	{
		return 0 + " / " + 0;
	}
}
