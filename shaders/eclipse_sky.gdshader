shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p);
 f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 vec3 d = normalize(EYEDIR);
 float h = max(d.y,0.0);
 vec3 col = mix(vec3(0.29,0.11,0.105),vec3(0.035,0.025,0.055),pow(h,0.5));
 vec2 p = d.xz / max(0.12,d.y+0.3) * 5.0;
 float cloud = noise(p)*0.52 + noise(p*2.1)*0.28 + noise(p*4.7)*0.13 + noise(p*11.0)*0.07;
 col = mix(col, vec3(0.065,0.043,0.065),smoothstep(0.35,0.68,cloud)*0.85);
 vec3 sun_dir = normalize(vec3(0.45,0.34,-1.0));
 float dist = length(d-sun_dir);
 float corona = exp(-abs(dist-0.068)*100.0);
 col += vec3(1.9,0.31,0.075)*corona;
 col += vec3(0.3,0.04,0.01)*exp(-dist*12.0);
 if(dist<0.060) { col = vec3(0.026,0.019,0.028); }
 COLOR = col;
}
