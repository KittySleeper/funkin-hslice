package funkin.ui;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;

import flixel.system.ui.FlxSoundTray;
import flixel.system.FlxAssets.FlxSoundAsset;

class FunkinSoundTray extends FlxSoundTray {
    public static final GRAPHIC_SCALE:Float = 0.3;

    public var barBitmapDatas:Map<Int, BitmapData> = [];
    var ownedBitmapDatas:Array<BitmapData> = [];

    public var trayContainer:Sprite;
    public var barDisplay:Bitmap;

    public var volumeMaxSound:FlxSoundAsset;

    public var lerpYPos:Float = 0;
    public var alphaTarget:Float = 0;

    private var _squashTimer:Float = 0;
    private var _shakeMult:Float = 0;

    public function new() {
        super();
        create();
    }

    private function create():Void {
        removeChildren();

        trayContainer = new Sprite();
        addChild(trayContainer);

        final bg:Bitmap = new Bitmap(loadTrayBitmap("soundtray/volumebox"));
        bg.smoothing = true;
        bg.scaleX = bg.scaleY = GRAPHIC_SCALE;
        trayContainer.addChild(bg);

        final backingBar:Bitmap = new Bitmap(loadTrayBitmap("soundtray/bars_10"));
        backingBar.x = 9;
        backingBar.y = 5;
        backingBar.smoothing = true;
        backingBar.alpha = 0.4;
        backingBar.scaleX = backingBar.scaleY = GRAPHIC_SCALE;
        trayContainer.addChild(backingBar);

        barDisplay = new Bitmap(loadTrayBitmap("soundtray/bars_10"));
        barDisplay.x = 9;
        barDisplay.y = 5;
        barDisplay.smoothing = true;
        barDisplay.scaleX = barDisplay.scaleY = GRAPHIC_SCALE;
        trayContainer.addChild(barDisplay);

        _bars = [];
        for(i in 1...11)
            barBitmapDatas.set(i, loadTrayBitmap("soundtray/bars_" + i));

        y = -88;
        visible = false;
        screenCenter();

        volumeUpSound = "assets/sounds/soundtray/up.ogg";
        volumeDownSound = "assets/sounds/soundtray/down.ogg";
        volumeMaxSound = "assets/sounds/soundtray/max.ogg";
    }

    function loadTrayBitmap(key:String):BitmapData
    {
        var bitmapData:BitmapData = Paths.image(key).bitmap.clone();
        ownedBitmapDatas.push(bitmapData);
        return bitmapData;
    }

    public function destroy():Void {
        for(bmp in ownedBitmapDatas) {
            bmp.disposeImage();
            bmp.dispose();
        }
        ownedBitmapDatas = null;
        barBitmapDatas = null;
    }

    override function update(MS:Float):Void {
        MS = Math.min(MS, FlxG.maxElapsed * 1000);

        y = FlxMath.lerp(y, lerpYPos, Math.min(FlxMath.getElapsedLerp(0.1, MS / 1000), 1));
        if(Math.abs(y + -88) < 0.01)
            y = -88;

        alpha = FlxMath.lerp(alpha, alphaTarget, Math.min(FlxMath.getElapsedLerp(0.25, MS / 1000), 1));

        if(_timer > 0) {
            _timer = Math.max(0, _timer - MS / 1000);

            if(_shakeMult > 0) {
                trayContainer.x = FlxG.random.float(-2, 2) * _shakeMult;
                trayContainer.y = FlxG.random.float(-2, 2) * _shakeMult;

                _shakeMult -= (MS / 1000) * 3;
            }
            if(_squashTimer > 0) {
                _squashTimer -= (MS / 1000);
                if(_squashTimer <= 0) {
                    scaleX = scaleY = _defaultScale;
                    screenCenter();
                }
            }
            alphaTarget = 1;
        }
        else if(y > -88) {
            lerpYPos = -88;
            alphaTarget = 0;
            trayContainer.x = trayContainer.y = 0;
        }
        if(_timer <= 0 && Math.floor(y) <= -88) {
            y = -88;

            visible = false;
            active = false;

            #if FLX_SAVE
            // Save sound preferences
            if(FlxG.save.isBound) {
                FlxG.save.data.mute = FlxG.sound.muted;
                FlxG.save.data.volume = FlxG.sound.volume;
                FlxG.save.flush();
            }
            #end
        }
    }

    /**
     * Makes the little volume tray slide out.
     *
     * @param	up Whether the volume is increasing.
     */
    override function showAnim(volume:Float, ?sound:FlxSoundAsset, duration = 1.0, label = "VOLUME"):Void {
        _timer = duration;
        lerpYPos = 10;
        alphaTarget = 1;

        visible = true;
        active = true;

        var globalVolume:Int = FlxG.sound.muted || FlxG.sound.volume == 0 ? 0 : Math.round(FlxG.sound.logToLinear(FlxG.sound.volume) * 10);
        if(!silent && sound != null)
            FlxG.sound.play(sound);

        if(globalVolume != 0) {
            barDisplay.bitmapData = barBitmapDatas.get(globalVolume);
            barDisplay.visible = true;
        } else
            barDisplay.visible = false;

        if(globalVolume == 10)
            _shakeMult = 1;
        else {
            _squashTimer = (1 / 18);
            scaleX = _defaultScale * 1.035;
            scaleY = _defaultScale * 0.965;
            screenCenter();
        }
    }

    override function showIncrement():Void {
		final volume = (!FlxG.sound.muted) ? FlxG.sound.volume : 0;
		final globalVolume:Int = (!FlxG.sound.muted) ? Math.round(FlxG.sound.volume * 10) : 0;
		showAnim(volume, (silent) ? null : ((globalVolume >= 10) ? volumeMaxSound : volumeUpSound));
	}

	override function showDecrement():Void {
		final volume = (!FlxG.sound.muted) ? FlxG.sound.volume : 0;
		showAnim(volume, (silent) ? null : volumeDownSound);
	}

    override function screenCenter():Void {
        if(trayContainer == null)
            return;

		x = (0.5 * (FlxG.stage.stageWidth - width) - FlxG.game.x);
	}
}