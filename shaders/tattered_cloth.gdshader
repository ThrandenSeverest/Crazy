shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(0.27,0.025,0.035,1.0);
uniform float wind_strength = 0.06;
void vertex() {
 float hem = UV.y;
 VERTEX.z += sin(TIME * 2.1 + VERTEX.x * 7.0 + hem * 3.0) * hem * wind_strength;
 VERTEX.x += sin(TIME * 1.6 + hem * 4.0) * hem * 0.025;
}
void fragment() {
 float weave = sin(UV.x * 650.0) * sin(UV.y * 650.0) * 0.055;
 float fold = 0.7 + 0.3 * sin(UV.x * 35.0 + UV.y * 2.0);
 float dirt = 1.0 - UV.y * 0.48;
 float tear = fract(sin(floor(UV.x * 47.0) * 127.1) * 43758.5);
 if (UV.y > 0.86 + tear * 0.14) { discard; }
 ALBEDO = cloth_color.rgb * (fold + weave) * dirt;
 ROUGHNESS = 0.98;
}
