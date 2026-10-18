#!/usr/bin/env python3
"""CRAZY hero asset source: deterministic, dependency-free modular GLB exporter.

Generated models are an INITIAL hard-surface sculpture blockout, NOT final reference
quality or a skin-weighted production character. Run python tools/build_hero.py.
Meshes share the same world coordinate space: +Y up, +Z forward, feet at Y=0.
Local Godot character origin should be at foot height. Units are meters.
"""
import json
import math
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
DEST = HERE / 'assets' / 'hero'
PI = math.pi
S = math.sin
C = math.cos

MATS = {
    'skin': (0.31, 0.22, 0.18, 0.0, 0.92),
    'undercoat': (0.055, 0.062, 0.066, 0.0, 0.93),
    'leather': (0.135, 0.066, 0.044, 0.0, 0.86),
    'black_iron': (0.12, 0.125, 0.13, 0.84, 0.43),
    'steel_edge': (0.34, 0.33, 0.30, 0.88, 0.32),
    'iron_shadow': (0.056, 0.057, 0.061, 0.75, 0.59),
    'silver': (0.50, 0.47, 0.40, 0.86, 0.30),
    'old_gold': (0.38, 0.27, 0.12, 0.83, 0.39),
    'crimson': (0.19, 0.024, 0.026, 0.0, 0.96),
    'crimson_edge': (0.085, 0.013, 0.015, 0.0, 0.99),
    'void': (0.018, 0.020, 0.020, 0.0, 0.99),
    'blood': (0.26, 0.015, 0.014, 0.18, 0.42),
}


def plus(a,b): return tuple(x+y for x,y in zip(a,b))
def minus(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,s): return tuple(x*s for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(v): return math.sqrt(dot(v,v))
def unit(v): return mul(v, 1/max(norm(v),1e-9))


class Part:
    def __init__(self,name,slot,pivot):
        self.name,self.slot,self.pivot = name,slot,pivot
        self.groups={}

    def triangle(self,a,b,c,material):
        group=self.groups.setdefault(material,[])
        if norm(cross(minus(b,a),minus(c,a))) < 1e-9: return
        group.append((a,b,c))

    def quad(self,a,b,c,d,m):
        self.triangle(a,b,c,m)
        self.triangle(a,c,d,m)

    def polygon(self,points,m):
        for i in range(1,len(points)-1):self.triangle(points[0],points[i],points[i+1],m)

    def tube(self,stations,m,segments=16,rib=0.0,cap=True):
        """Sections: center (xyz), radii (x,z). Tangent-adaptive ellipse ring loft."""
        rings=[]
        for i,(center,rx,rz) in enumerate(stations):
            tangent=unit(minus(stations[min(i+1,len(stations)-1)][0],stations[max(0,i-1)][0]))
            u=unit(cross((0,0,1),tangent))
            if norm(u)<0.2:u=unit(cross((1,0,0),tangent))
            v=unit(cross(tangent,u))
            ring=[]
            for j in range(segments):
                phi=2*PI*j/segments
                scallop=1+rib*C(phi*8)
                p=plus(center,plus(mul(u,rx*C(phi)*scallop),mul(v,rz*S(phi)*scallop)))
                ring.append(p)
            rings.append(ring)
        for a,b in zip(rings[:-1],rings[1:]):
            for j in range(segments):
                q=(j+1)%segments
                self.quad(a[j],a[q],b[q],b[j],m)
        if cap:
            for j in range(segments):
                q=(j+1)%segments
                self.triangle(stations[0][0],rings[0][q],rings[0][j],m)
                self.triangle(stations[-1][0],rings[-1][j],rings[-1][q],m)

    def round(self,center,r,m,rings=6,steps=10):
        loops=[]
        for i in range(1,rings):
            phi=PI*i/rings
            y=center[1]+r*S(phi-PI/2)
            rx=r*C(phi-PI/2)
            loops.append(((center[0],y,center[2]),rx,rx))
        self.tube([((center[0],center[1]-r,center[2]),.0001,.0001)]+loops+[((center[0],center[1]+r,center[2]),.0001,.0001)],m,steps)

    def blade(self,a,b,width,thick,m):
        """Six-sided beveled plate between two points, with a raised central ridge."""
        along=unit(minus(b,a)); side=unit(cross((0,0,1),along))
        if norm(side)<.1:side=(1,0,0)
        depth=unit(cross(along,side))
        u=mul(side,width/2); v=mul(depth,thick/2)
        p=[plus(a,plus(mul(u,x),mul(v,z))) for x,z in [(-1,0),(0,1),(1,0),(0,-1)]]
        q=[plus(b,plus(mul(u,x),mul(v,z))) for x,z in [(-1,0),(0,1),(1,0),(0,-1)]]
        for i in range(4):self.quad(p[i],p[(i+1)%4],q[(i+1)%4],q[i],m)
        self.polygon(list(reversed(p)),m);self.polygon(q,m)

    def strip(self,points,width,m,depth=.008):
        for a,b in zip(points[:-1],points[1:]): self.blade(a,b,width,depth,m)

    def spike(self,a,b,base,m,segments=8):
        self.tube([(a,base,base), (plus(a,mul(minus(b,a),.16)),base*.9,base*.9),
                   (plus(a,mul(minus(b,a),.76)),base*.13,base*.13),(b,.001,.001)],m,segments)

    def cloth(self,top,bottom,halfwidth,zfront,zback,material,hem):
        """Hanging strip with multiple noncoplanar vertical folds and torn hem."""
        cols=24;rows=13;grid=[]
        for i in range(rows+1):
            t=i/rows;y=top+(bottom-top)*t
            ring=[]
            for j in range(cols+1):
                u=j/cols*2-1
                x=u*halfwidth*(.70+.28*t)
                z=zfront+(zback-zfront)*t+.04*S(u*PI*4+t*4)+.025*C(u*PI*9)
                tear=(.035*S((j*11+3)*2.71)+.035*C((j*5+2)*2.73)) if i==rows else 0
                ring.append((x,y+tear,z))
            grid.append(ring)
        for i in range(rows):
            for j in range(cols): self.quad(grid[i][j],grid[i][j+1],grid[i+1][j+1],grid[i+1][j],material)
        self.strip([grid[rows][i] for i in range(cols+1)],.011,hem)


def limb(part,a,b,ra,rb,material,steps=18,bulge=.09):
    middle=plus(a,mul(minus(b,a),.48))
    st=[(a,ra*.72,ra*.72), (plus(a,mul(minus(b,a),.16)),ra*.97,ra*.97),
        (middle,max(ra,rb)*(.86+bulge),max(ra,rb)*(.83+bulge)),
        (plus(a,mul(minus(b,a),.80)),rb*.99,rb*.96),(b,rb,rb)]
    part.tube(st,material,steps)


def rivet_row(part,coords,m='old_gold',r=.011):
    for c in coords:part.round(c,r,m,4,7)

parts=[]
def create(name,slot,pivot):
    p=Part(name,slot,pivot);parts.append(p);return p

# Anatomy: segmented by true articulation pivots; geometry in shared absolute coordinates.
root=create('body_torso','body',(0,0,0))
root.tube([((0,.94,0),.21,.135),((0,1.04,-.008),.20,.126),((0,1.18,-.005),.18,.122),
           ((0,1.33,-.015),.247,.157),((0,1.46,-.022),.275,.17),
           ((0,1.56,-.03),.29,.132),((0,1.61,-.032),.11,.082)],'undercoat',24)
root.tube([((0,1.56,0),.083,.075),((0,1.65,0),.078,.077)],'skin',16)
head=create('body_head','body',(0,1.62,0))
head.tube([((0,1.64,0),.094,.10),((0,1.69,.012),.112,.11),((0,1.78,.012),.113,.115),
           ((0,1.865,.006),.108,.102),((0,1.936,-.006),.067,.077)],'skin',22)
head.tube([((0,1.906,-.014),.09,.082),((0,1.955,-.016),.067,.059)],'undercoat',18)
for side in (-1,1):
    a=(side*.31,1.53,0);b=(side*.414,1.135,.002);c=(side*.48,.835,.035)
    p=create(('body_left_arm' if side==-1 else 'body_right_arm'),'body',(side*.31,1.53,0))
    limb(p,a,b,.11,.085,'undercoat');limb(p,b,c,.087,.055,'undercoat')
    limb(p,c,(side*.50,.708,.057),.064,.052,'leather',14,.0)
    p=create(('body_left_leg' if side==-1 else 'body_right_leg'),'body',(side*.135,.96,0))
    limb(p,(side*.135,.96,0),(side*.156,.555,.0),.152,.108,'undercoat',20)
    limb(p,(side*.156,.555,0),(side*.15,.145,-.005),.105,.066,'undercoat',20)
    p.tube([((side*.15,.145,.01),.095,.105),((side*.15,.095,.09),.105,.15),((side*.15,.07,.22),.114,.09),((side*.15,.07,.31),.096,.06)],'leather',18)

cuirass=create('armor_cuirass','chest',(0,0,0))
cuirass.tube([((0,1.075,-.005),.224,.142),((0,1.145,-.005),.21,.148),
              ((0,1.24,-.012),.223,.153),((0,1.37,-.020),.270,.183),
              ((0,1.47,-.03),.31,.172),((0,1.54,-.028),.299,.139),
              ((0,1.585,-.018),.22,.105)],'black_iron',24,rib=.022)
# central Gothic ridge and pointed V breastplate, ribs
cuirass.strip([(0,1.575,.12),(0,1.45,.163),(0,1.30,.187),(0,1.17,.156),(0,1.085,.126)],.026,'steel_edge')
for s in (-1,1):
    cuirass.strip([(0,1.42,.18),(s*.14,1.36,.157),(s*.25,1.27,.087)],.017,'iron_shadow')
    cuirass.strip([(s*.03,1.54,.13),(s*.22,1.485,.103),(s*.292,1.42,.055)],.017,'steel_edge')
    cuirass.strip([(s*.22,1.53,.06),(s*.29,1.485,.01),(s*.297,1.40,.0)],.035,'steel_edge')
    rivet_row(cuirass,[(s*x,1.535,.07) for x in (.12,.23)],r=.012)
for y,rr in [(1.12,.205),(1.19,.218),(1.26,.235)]:
    cuirass.strip([(-rr,y,.05),(-rr*.72,y-.012,.122),(0,y-.014,.171),(rr*.72,y-.012,.122),(rr,y,.05)],.012,'silver')
# Waist, layered skirt and free-hanging overlapping platelets
faulds=create('armor_faulds','waist',(0,0,0))
faulds.tube([((0,1.12,0),.222,.163),((0,1.07,0),.226,.165),((0,1.01,0),.239,.17)],'iron_shadow',24)
for tier in range(3):
    y=1.03-tier*.075
    faulds.tube([((0,y,0),.232+tier*.025,.171+tier*.018),((0,y-.06,0),.255+tier*.027,.176+tier*.02)],'black_iron',24,cap=False)
    for side in (-1,1):
        rivet_row(faulds,[(side*.15,y-.044,.09)],'silver',.012)
for side in (-1,1):
    # front pointed tassets with raised edge, separate from legs
    center=side*.16
    faulds.blade((center,.91,.18),(center,.67,.17),.17,.025,'black_iron')
    faulds.strip([(center-.077,.88,.177),(center,.69,.193),(center+.077,.88,.177)],.012,'steel_edge')
faulds.blade((0,1.09,.192),(0,.88,.214),.19,.016,'crimson')
faulds.blade((0,1.09,.199),(0,.88,.221),.016,.005,'old_gold')

helmet=create('armor_helmet','head',(0,1.62,0))
helmet.tube([((0,1.66,0),.125,.13),((0,1.73,0),.136,.146),((0,1.82,-.01),.134,.137),
             ((0,1.925,-.015),.118,.120),((0,2.00,-.023),.091,.085),((0,2.04,-.023),.04,.035)],'black_iron',24,rib=.035)
# True dark eye gaps, forehead brow and front vertical visor ribs.
helmet.blade((-.115,1.831,.131),(.115,1.831,.131),.019,.03,'iron_shadow')
for s in (-1,1):
    helmet.blade((s*.014,1.832,.144),(s*.107,1.835,.105),.025,.013,'void')
    helmet.blade((s*.010,1.852,.14),(s*.12,1.855,.091),.016,.01,'steel_edge')
    helmet.blade((s*.119,1.82,.076),(s*.105,1.65,.091),.065,.014,'black_iron')
for x in [-.088,-.044,0,.044,.088]:
    helmet.blade((x,1.79,.146),(x,1.673,.139),.016,.014,'steel_edge')
helmet.strip([(0,2.03,.021),(0,1.97,.10),(0,1.84,.147)],.025,'silver')
for i in range(7):
    angle=2*PI*i/7+PI/14
    x=.103*C(angle);z=.10*S(angle)-.012
    h=.18 if i in (0,3,4) else .115
    helmet.spike((x,1.991,z),(x*1.48,2.03+h,z*1.48),.022,'black_iron')
    helmet.spike((x,2.00,z),(x*1.46,2.035+h,z*1.45),.010,'steel_edge')

for side in (-1,1):
    a=(side*.31,1.53,0);el=(side*.414,1.135,.002);wr=(side*.48,.835,.035)
    shoulder=create('armor_pauldron_L' if side==-1 else 'armor_pauldron_R',
                    'shoulder_L' if side==-1 else 'shoulder_R',a)
    for i in range(4):
        center=plus(a,(side*(.01+i*.025),-.025-i*.059,-.007))
        shoulder.tube([(plus(center,(0,.065,0)),.178-i*.008,.155-i*.004),
                       (center,.193-i*.006,.163),
                       (plus(center,(0,-.078,0)),.176-i*.007,.152)],
                      'black_iron' if i%2==0 else 'iron_shadow',24,rib=.035,cap=False)
        rivet_row(shoulder,[(center[0]+side*.10,center[1],.127),(center[0]-side*.12,center[1],.115)],r=.011)
    shoulder.spike((side*.49,1.58,-.01),(side*.61,1.79,-.055),.067,'black_iron')
    shoulder.spike((side*.49,1.58,-.01),(side*.61,1.80,-.055),.025,'steel_edge')
    elbow=create('armor_vambrace_L' if side==-1 else 'armor_vambrace_R',
                'arm_L' if side==-1 else 'arm_R',a)
    elbow.tube([(el,.107,.105),(plus(el,mul(minus(wr,el),.27)),.105,.099),
                (plus(el,mul(minus(wr,el),.67)),.083,.075),(wr,.079,.068)],'black_iron',20,rib=.035)
    for k in (.16,.48,.86):
        cen=plus(el,mul(minus(wr,el),k))
        elbow.tube([(plus(cen,(0,.012,0)),.096,.09),(plus(cen,(0,-.016,0)),.099,.093)],'steel_edge',16,cap=False)
    elbow.spike((side*.416,1.128,.098),(side*.460,1.13,.235),.047,'black_iron')
    gauntlet=create('armor_gauntlet_L' if side==-1 else 'armor_gauntlet_R','arm_L' if side==-1 else 'arm_R',a)
    gauntlet.tube([(wr,.082,.072),((side*.492,.77,.05),.078,.067),((side*.512,.707,.071),.063,.051)],'black_iron',18)
    for j in range(4):
        x=side*(.474+j*.014)
        gauntlet.blade((x,.729,.101),(x,.672,.11),.02,.018,'steel_edge')

    thigh=(side*.135,.96,0);knee=(side*.156,.555,0);ankle=(side*.15,.145,-.005)
    leg=create('armor_greave_L' if side==-1 else 'armor_greave_R','leg_L' if side==-1 else 'leg_R',thigh)
    leg.tube([((side*.145,.62,0),.118,.131),((side*.155,.565,.015),.132,.141),
              ((side*.155,.50,.025),.115,.138),((side*.153,.40,0),.117,.111),
              ((side*.15,.23,-.01),.083,.094),((side*.15,.14,-.008),.086,.088)],'black_iron',22,rib=.034)
    leg.spike((side*.156,.556,.153),(side*.158,.51,.258),.055,'steel_edge')
    for z in (0.104,-.09):
        leg.strip([(side*.15,.57,z),(side*.15,.37,z*.8),(side*.15,.18,z*.62)],.018,'steel_edge')
    boot=create('armor_sabaton_L' if side==-1 else 'armor_sabaton_R','leg_L' if side==-1 else 'leg_R',thigh)
    boot.tube([((side*.15,.15,.00),.10,.11),((side*.15,.108,.095),.12,.14),
               ((side*.15,.086,.205),.125,.106),((side*.15,.075,.325),.108,.068)],'black_iron',20)
    for z in (.135,.20,.266):
        boot.blade((side*.034,.104,z),(side*.269,.104,z),.016,.012,'steel_edge')

# Hanging cloak intentionally stays its own file / runtime slot.
cloak=create('armor_cloak','cloak',(0,0,0))
cloak.cloth(1.55,.13,.62,-.165,-.39,'crimson','crimson_edge')
for s in (-1,1):
    cloak.blade((s*.255,1.59,-.115),(s*.41,1.35,-.20),.13,.015,'crimson')
    rivet_row(cloak,[(s*.21,1.547,-.137)],r=.02)
# black stitched sigil stripes
cloak.strip([(0,1.37,-.245),(0,1.18,-.27),(0,.83,-.32)],.029,'crimson_edge')
for s in (-1,1):cloak.strip([(0,1.12,-.29),(s*.16,.96,-.32),(0,.76,-.335)],.023,'crimson_edge')

sword=create('weapon_longsword','weapon',(0,0,0))
# Resting at right side, pointed down. Slot independent of gauntlet for future attachment.
sword.blade((.54,.87,.20),(.55,.16,.43),.113,.034,'steel_edge')
sword.strip([(.543,.78,.223),(.547,.27,.408)],.011,'iron_shadow')
sword.blade((.46,.89,.183),(.61,.88,.196),.050,.028,'old_gold')
sword.blade((.535,.9,.183),(.53,1.075,.125),.049,.042,'leather')
sword.round((.529,1.085,.12),.043,'old_gold')
for s in (-1,1): sword.spike((.54+s*.08,.885,.19),(.54+s*.14,.939,.18),.021,'black_iron')


def export(part,path):
    """Write standards-compliant uncompressed glTF 2 GLB with PBR materials.
    No UV: all surfaces have solid PBR colors; this is not final textured art."""
    buffer=bytearray(); views=[]; accessors=[]; primitives=[]
    def append(data,target):
        while len(buffer)%4:buffer.append(0)
        offset=len(buffer);buffer.extend(data)
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data),'target':target})
        return len(views)-1
    mat_names=list(part.groups)
    materials=[]
    for name in mat_names:
        r,g,b,metal,rough=MATS[name]
        materials.append({'name':name,'doubleSided':True,'pbrMetallicRoughness':{
            'baseColorFactor':[r,g,b,1], 'metallicFactor':metal,'roughnessFactor':rough}})
    tri_total=0
    for mat_index,material in enumerate(mat_names):
        triangles=part.groups[material];positions=[];normals=[]
        for a,b,c in triangles:
            normal=unit(cross(minus(b,a),minus(c,a)))
            positions.extend((a,b,c));normals.extend((normal,normal,normal))
        if not positions:continue
        tri_total+=len(triangles)
        flatp=[v for p in positions for v in p];flatn=[v for p in normals for v in p]
        vpos=append(struct.pack('<%sf'%len(flatp),*flatp),34962)
        vnorm=append(struct.pack('<%sf'%len(flatn),*flatn),34962)
        mins=[min(p[i] for p in positions) for i in range(3)]
        maxs=[max(p[i] for p in positions) for i in range(3)]
        a=len(accessors)
        accessors.append({'bufferView':vpos,'componentType':5126,'count':len(positions),'type':'VEC3','min':mins,'max':maxs})
        accessors.append({'bufferView':vnorm,'componentType':5126,'count':len(normals),'type':'VEC3'})
        primitives.append({'attributes':{'POSITION':a,'NORMAL':a+1},'material':mat_index,'mode':4})
    gltf={'asset':{'version':'2.0','generator':'CRAZY procedural hero alpha'},
          'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':part.name,'mesh':0}],
          'meshes':[{'name':part.name,'primitives':primitives}],
          'buffers':[{'byteLength':len(buffer)}], 'bufferViews':views,
          'accessors':accessors,'materials':materials}
    j=json.dumps(gltf,separators=(',',':')).encode('utf8')
    while len(j)%4:j+=b' '
    while len(buffer)%4:buffer.append(0)
    out=struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(buffer))
    out+=struct.pack('<I4s',len(j),b'JSON')+j
    out+=struct.pack('<I4s',len(buffer),b'BIN\x00')+buffer
    path.write_bytes(out)
    return tri_total


def main():
    DEST.mkdir(parents=True,exist_ok=True)
    manifest={'format':'crazy-hero-v1','units':'meters','axis':'Y_up_Z_front',
              'quality':'technical hard-surface alpha, not approved final art', 'parts':[]}
    for p in parts:
        filename=f'{p.name}.glb'
        count=export(p,DEST/filename)
        manifest['parts'].append({'name':p.name,'slot':p.slot,'pivot':p.pivot,'file':filename,'triangles':count})
    (DEST/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    print('Hero parts:',len(parts),'triangles:',sum(q['triangles'] for q in manifest['parts']))
    for entry in manifest['parts']:
        print(f"  {entry['name']:<23} {entry['triangles']:>6} triangles")

if __name__=='__main__':main()