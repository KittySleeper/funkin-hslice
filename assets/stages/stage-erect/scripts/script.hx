function createPost() {
    var boyfriend:Character = strumLines.members[1].characters[0];

    boyfriend.shader = new CustomShader("adjustColor");
    boyfriend.shader.set("brightness", -23);
    boyfriend.shader.set("hue", 12);
    boyfriend.shader.set("contrast", 7);
    boyfriend.shader.set("saturation", 0);

    var dad:Character = strumLines.members[0].characters[0];

    dad.shader = new CustomShader("adjustColor");
    dad.shader.set("brightness", -33);
    dad.shader.set("hue", -32);
    dad.shader.set("contrast", -23);
    dad.shader.set("saturation", 0);

    var gf:Character = strumLines.members[2].characters[0];

    gf.shader = new CustomShader("adjustColor");
    gf.shader.set("brightness", -30);
    gf.shader.set("hue", -9);
    gf.shader.set("contrast", -4);
    gf.shader.set("saturation", 0);
}