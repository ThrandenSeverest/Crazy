shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.19, 0.20, 0.22, 1.0);
uniform float metalness = 0.85;
varying vec3 local_pos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() { local_pos = VERTEX; }
void fragment() {
 vec3 cell = floor(local_pos * 120.0);
 float grain = hash(cell);
 float pits = step(0.985, hash(floor(local_pos * 55.0)));
 float scratch = pow(abs(sin(local_pos.y * 1800.0 + sin(local_pos.x * 45.0) * 8.0)), 80.0);
 ALBEDO = base_color.rgb * (0.90 + grain * 0.13) + vec3(scratch * 0.012);
 ALBEDO = mix(ALBEDO, vec3(0.095, 0.055, 0.037), pits * 0.5);
 METALLIC = metalness;
 ROUGHNESS = clamp(0.48 + grain * 0.08 + pits * 0.08, 0.0, 1.0);
}
