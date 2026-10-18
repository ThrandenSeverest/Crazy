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
 float fold = 0.82 + 0.15 * sin(UV.x * 27.0 + UV.y * 2.0);
 float dirt = 1.0 - UV.y * 0.48;
 float tear = fract(sin(floor(UV.x * 47.0) * 127.1) * 43758.5);
 if (UV.y > 0.86 + tear * 0.14) { discard; }
 vec3 fabric = cloth_color.rgb * (fold + weave) * dirt;
 float trunk = (1.0-step(0.012,abs(UV.x-0.5)))*step(0.20,UV.y)*(1.0-step(0.57,UV.y));
 float wings = (1.0-step(0.012,abs(abs(UV.x-0.5)-(0.55-UV.y)*0.60)))*step(0.22,UV.y)*(1.0-step(0.51,UV.y));
 float crown = (1.0-step(0.012,abs(abs(UV.x-0.5)-(UV.y-0.14)*1.1)))*step(0.14,UV.y)*(1.0-step(0.22,UV.y));
 float crest = max(max(trunk,wings),crown);
 float wear = step(0.23,fract(sin(dot(floor(UV*160.0),vec2(127.1,311.7)))*43758.5453));
 ALBEDO = mix(fabric,vec3(0.24,0.16,0.08)*(fold+weave),crest*wear*0.68);
 ROUGHNESS = 0.98;
}
