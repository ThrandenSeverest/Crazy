shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.28, 0.27, 0.26, 1.0);
uniform bool paving = false;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
}
void fragment() {
 vec3 n = abs(world_normal);
 vec2 uv = world_pos.xy;
 if(n.x > n.z) { uv = world_pos.zy; }
 if(n.y > 0.65) { uv = world_pos.xz; }
 uv *= vec2(1.45, 3.2);
 float row = floor(uv.y);
 uv.x += mod(row,2.0) * 0.5;
 vec2 id = floor(uv);
 vec2 f = fract(uv);
 float edge = min(min(f.x,1.0-f.x), min(f.y,1.0-f.y));
 float mortar = smoothstep(0.018,0.065,edge);
 float variation = hash(id);
 float grain = hash(floor(world_pos.xz * 110.0 + world_pos.y * 19.0));
 vec3 stone = base_color.rgb * (0.65 + variation * 0.65) * (0.82 + grain * 0.3);
 float erosion = step(0.965, hash(floor(uv * 37.0)));
 stone *= 1.0 - erosion * 0.36;
 ALBEDO = mix(base_color.rgb * 0.28, stone, mortar);
 ROUGHNESS = 0.88;
 METALLIC = paving ? 0.12 : 0.0;
}
