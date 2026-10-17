package funkin.states.game.objects;

class HealthIcon extends FlxSprite {
    public var health:Float = 50;
    public var isPlayer:Bool = false;
    public var characterName:String = "bf";
    public var healthSteps:Map<Int, String> = [
        50 => "neutral",
        5 => "losing"
    ];
    public var defaultScale:Float = 1;
    public var bumpMultiplier:Float = .25;

    override public function new(x:Float, y:Float, characterName:String = "bf", isPlayer:Bool = false) {
        super(x, y);

        this.characterName = characterName;
        this.isPlayer = isPlayer;

        if (Paths.exists('characters/$characterName/icon.png'))
            loadGraphic(Paths.image('icon', 'characters/$characterName'), true, 150, 150);
        animation.add('neutral', [0]);
        animation.add('losing', [1]);
        animation.play('neutral');

        if (this.isPlayer)
            flipX = !flipX;
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        scale.set(
            CoolUtil.coolLerp(defaultScale, scale.x, 0.9, elapsed),
            CoolUtil.coolLerp(defaultScale, scale.y, 0.9, elapsed)
        );

        var iconHealth:Float = isPlayer ? health : 100 - health;
        var thresholds:Array<Int> = [for (threshold in healthSteps.keys()) threshold];
        thresholds.sort(function(a:Int, b:Int):Int return a - b);

        if (thresholds.length == 0)
            return;

        var healthAnimation:String = healthSteps.get(thresholds[thresholds.length - 1]);
        for (threshold in thresholds)
        {
            if (iconHealth <= threshold)
            {
                healthAnimation = healthSteps.get(threshold);
                break;
            }
        }

        if (animation.exists(healthAnimation) && (animation.curAnim == null || animation.curAnim.name != healthAnimation))
            animation.play(healthAnimation);
    }

    public function bop():Void
    {
        var bopScale:Float = defaultScale * (1 + bumpMultiplier);
        scale.set(bopScale, bopScale);
    }
}