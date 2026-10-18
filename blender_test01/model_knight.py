"""CRAZY test 01. All geometry, materials, cameras and .blend are generated INSIDE Blender.
Run: blender -b -t 4 --python model_knight.py -- /path/to/output
No externally generated GLB, no Godot, no game engine.
"""
import bpy, math, os, sys, random
from mathutils import Vector
from math import sin, cos, pi
random.seed(19)
OUT = sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else '/tmp/knight'
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for datablock in list(bpy.data.materials): bpy.data.materials.remove(datablock)

# Organized, editable Blender scene: each armor slot is its own collection.
def collection(name):
    c=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c); return c
cols={name:collection(name) for name in ['00_BODY','01_HELMET','02_CUIRASS','03_SHOULDERS','04_ARMS','05_GAUNTLETS','06_WAIST','07_LEGS','08_BOOTS','09_CAPE','10_SWORD','11_STUDIO']}
def move(obj, group):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    cols[group].objects.link(obj)
    return obj

def mat(name, col, metallic=0, rough=.5, noise_scale=0, bump=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    n=m.node_tree.nodes; p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1)
    p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=rough
    if noise_scale:
        tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=noise_scale; tex.inputs['Detail'].default_value=3.2
        bumpnode=n.new('ShaderNodeBump');bumpnode.inputs['Strength'].default_value=bump;bumpnode.inputs['Distance'].default_value=.023
        m.node_tree.links.new(tex.outputs['Fac'],bumpnode.inputs['Height']);m.node_tree.links.new(bumpnode.outputs['Normal'],p.inputs['Normal'])
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.19;ramp.color_ramp.elements[0].color=(*tuple(x*.54 for x in col),1)
        ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(*tuple(min(x*1.32,1) for x in col),1)
        m.node_tree.links.new(tex.outputs['Fac'],ramp.inputs['Fac']);m.node_tree.links.new(ramp.outputs['Color'],p.inputs['Base Color'])
    return m
steel=mat('Blackened forged iron | mottled',(.087,.09,.102),1,.32,50,.16)
polished=mat('Charcoal polished plate',(.142,.15,.164),.94,.25,34,.09)
edge=mat('Worn bright steel bevel edges',(.35,.36,.36),.91,.31,45,.1)
gold=mat('Aged bronze / brass filigree',(.33,.245,.117),.85,.3,44,.1)
leather=mat('Dark oiled leather',(.069,.035,.033),.1,.8,60,.2)
cloth=mat('Deep torn oxblood cloth',(.20,.018,.027),.03,.92,87,.3)
black=mat('Deep void visor',(.005,.006,.01),.1,.52)
skin=mat('Unexposed mannequin body',(.12,.092,.077),.03,.74)
mail=mat('Worn chainmail / fine cells',(.052,.055,.063),.83,.41,190,.36)

# Contour surfaces are designed directly in Blender, not imported triangular GLBs.
def mesh(name,verts,faces,material,group, bevel=0,subdiv=0):
    me=bpy.data.meshes.new(name+' Geometry');me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);cols[group].objects.link(ob)
    ob.data.materials.append(material)
    for poly in me.polygons:poly.use_smooth=True
    if subdiv:
        md=ob.modifiers.new('Sculpted surface subdivision', 'SUBSURF');md.levels=subdiv;md.render_levels=subdiv
    if bevel:
        b=ob.modifiers.new('Hand-worn rim / edge glints','BEVEL');b.width=bevel;b.segments=3
        if hasattr(b,'affect'): b.affect='EDGES'
        normal=ob.modifiers.new('Weighted plate normals','WEIGHTED_NORMAL');normal.keep_sharp=True
    return ob

def ellipsoid(name,location,scale,material,group,res=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=res,ring_count=16,location=location)
    o=bpy.context.object;o.name=name;o.scale=scale;move(o,group);o.data.materials.append(material)
    for f in o.data.polygons:f.use_smooth=True
    return o

def rings(name, stations, material, group, resolution=24, caps=True, bevel=.006):
    # each station: x,y,z,rx,ry. Organic profile loft, curved body surfaces.
    V=[];F=[]
    for x,y,z,rx,ry in stations:
        for k in range(resolution):
            a=2*pi*k/resolution
            V.append((x+rx*sin(a),y-ry*cos(a),z))
    for j in range(len(stations)-1):
        for k in range(resolution):
            a=j*resolution+k;b=j*resolution+(k+1)%resolution
            F.append((a,b,b+resolution,a+resolution))
    if caps:
        F.append(tuple(reversed(tuple(range(resolution)))))
        F.append(tuple((len(stations)-1)*resolution+k for k in range(resolution)))
    return mesh(name,V,F,material,group,bevel)

def surface(name, vfunc, nu,nv,material,group,solid=.0,subdiv=1):
    vs=[vfunc(i/(nu-1),j/(nv-1)) for j in range(nv) for i in range(nu)]
    fs=[]
    for j in range(nv-1):
        for i in range(nu-1):
            a=j*nu+i;fs.append((a,a+1,a+nu+1,a+nu))
    obj=mesh(name,vs,fs,material,group,0,subdiv)
    if solid:
        m=obj.modifiers.new('Forged plate thickness','SOLIDIFY');m.thickness=solid;m.offset=0
        b=obj.modifiers.new('Rolled and worn rim','BEVEL');b.width=.007;b.segments=2
        w=obj.modifiers.new('Balanced vertex normals','WEIGHTED_NORMAL');w.keep_sharp=True
    return obj

def path(name, pts, diameter,material,group):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=diameter/2;cu.bevel_resolution=3;cu.resolution_u=16
    poly=cu.splines.new('POLY');poly.points.add(len(pts)-1)
    for p,co in zip(poly.points,pts):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);cols[group].objects.link(ob);ob.data.materials.append(material)
    return ob

def rivet(name,pos,r,group):
    o=ellipsoid(name,pos,(r,r,r*.42),gold,group,12);return o

def tapered_spike(name,base,tip,base_w,material,group):
    v0=Vector(base);v1=Vector(tip);direction=(v1-v0).normalized(); tangent=direction.cross(Vector((0,1,0))).normalized()
    if tangent.length<.1:tangent=direction.cross(Vector((1,0,0))).normalized()
    other=direction.cross(tangent).normalized()
    verts=[]
    for x,y in [(1,0),(0,1),(-1,0),(0,-1)]:verts.append(tuple(v0+base_w*(x*tangent+y*other)))
    verts.append(tuple(v1));faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)]
    return mesh(name,verts,faces,material,group,.003)

# Mannequin understructure, all parts are genuine mesh objects, not fused armor.
rings('Tailored gambeson torso',[(0,0,1.09,.23,.135),(0,0,1.33,.28,.16),(0,0,1.56,.31,.17),(0,.005,1.69,.235,.15)],leather,'00_BODY',32)
rings('Neck | flexible undersuit',[(0,0,1.65,.105,.095),(0,0,1.87,.095,.086)],black,'00_BODY')
ellipsoid('Organic head under helmet',(0,0,1.95),(.135,.13,.18),skin,'00_BODY')
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    rings(f'Gambeson arm {side}',[(sign*.255,0,1.64,.113,.11),(sign*.38,0,1.5,.102,.10),(sign*.43,-.015,1.27,.084,.082),(sign*.46,-.025,1.09,.069,.07)],leather,'00_BODY',18)
    rings(f'Trousers {side}',[(sign*.13,0,1.07,.13,.13),(sign*.14,.004,.85,.135,.125),(sign*.155,-.006,.61,.105,.11),(sign*.165,0,.42,.10,.09),(sign*.17,-.005,.14,.093,.092)],black,'00_BODY',20)

# Breast cuirass: separate anatomically convex front/rear shaped shells, not a capsule.
def chest(u,v):
    theta=(-.52+u*1.04)*pi
    z=1.18+.50*v
    rx=.235+.065*sin(pi*v)**.8-.042*v
    ry=.132+.075*sin(pi*v)**.9
    chest_bulge=.025*math.exp(-((v-.69)/.24)**2)
    x=rx*sin(theta)
    y=-(ry+chest_bulge)*cos(theta)-.011*math.sin(2*theta)**2
    z+=.027*cos(theta)*sin(pi*v)
    return (x,y,z)
surface('Breastplate | sculpted three-dimensional convexity',chest,21,16,polished,'02_CUIRASS',.019,2)
# V-shaped interlocking lower breast plates.
for j in range(4):
    lo=1.11+j*.082
    def stomach(u,v,j=j,lo=lo):
        theta=(u-.5)*2.68
        zz=lo+v*.085-.024*(1-abs(2*u-1))
        r=.245+.022*sin(j*.8)-.03*v
        return (r*sin(theta),-(.145+.01*j)*cos(theta)-.009*(1-v),zz)
    surface(f'Articulating abdominal lamella {j+1:02d}',stomach,16,5,steel,'02_CUIRASS',.013,1)
# Chest central keel & carved diagonal rib relief.
path('Central forged ridge',[(0,-.238,1.67),(0,-.238,1.56),(0,-.208,1.43),(0,-.180,1.25)],.019,edge,'02_CUIRASS')
for s in (-1,1):
    for i in range(3):
        pts=[]
        for k in range(16):
            u=k/15
            pts.append((s*(.038+.19*u),-.237+.043*u*u,1.60-i*.082-.07*u+.014*sin(pi*u)))
        path(f'Engraved rib fillet {s} / {i}',pts,.008,gold,'02_CUIRASS')
    pts=[(s*.215,-.117,1.66),(s*.284,-.072,1.55),(s*.28,-.080,1.32),(s*.235,-.12,1.18)]
    path(f'Cuirass outer rolled trim {s}',pts,.018,edge,'02_CUIRASS')
    for z in [1.25,1.38,1.52]:rivet(f'Cuirass left-right bronze fastener {s} {z}',(s*.242,-.123,z),.010,'02_CUIRASS')
# Backplate also independent.
def back(u,v):
    a=(u-.5)*2.98;z=1.12+.55*v
    r=.247+.037*sin(pi*v)-.045*v
    return (r*sin(a),(.132+.026*sin(pi*v))*cos(a),z)
surface('Upper backplate shell',back,18,13,steel,'02_CUIRASS',.014,1)

# Helm: loft separate crown, segmented grim face visor, pointed brow; spike geometry.
rings('Great helm | forged skull',[(0,-.003,1.835,.133,.132),(0,-.003,1.91,.155,.15),(0,0,2.027,.163,.152),(0,.015,2.135,.143,.14),(0,.018,2.195,.09,.095)],steel,'01_HELMET',40)
# Continuous chin plate and welded cheekguards.
def faceguard(u,v):
    a=(u-.5)*2.19;z=1.854+.236*v
    return (.159*sin(a),-(.154+.012*sin(pi*v))*cos(a)-.009,z+.009*sin(pi*u))
surface('Black visor | slotted faceplate',faceguard,16,12,polished,'01_HELMET',.012,1)
# Visor slits and articulated slat grille.
path('Visor horizontal black ocular slit',[(x,-.171,2.038+.007*cos(x*10)) for x in [-.117,-.09,-.06,-.03,0,.03,.06,.09,.117]],.026,black,'01_HELMET')
for k in range(-3,4):
    x=k*.032
    path(f'Breathe grille / {k}',[(x,-.169,1.905),(x,-.177,1.973)],.014,black,'01_HELMET')
    path(f'Forged vertical cage / {k}',[(x+.008,-.178,1.896),(x+.008,-.181,1.968)],.006,edge,'01_HELMET')
for z in [1.875,2.108,2.145]:
    path(f'Helm engraved cross-ridge at {z}',[(x,-.166-0.01*(1-abs(x)/.14),z+.012*(1-abs(x)/.14)) for x in [-.13,-.095,-.05,0,.05,.095,.13]],.012,gold,'01_HELMET')
for s in (-1,1):
    surface(f'Gothic cheek flared wing {s}',lambda u,v,s=s:(s*(.12+.045*u),-.132+.06*u,1.82+.24*v-.04*u*sin(pi*v)),8,10,steel,'01_HELMET',.009,1)
    for z in [1.885,2.014]:rivet(f'Helm rivet {s} / {z}',(s*.143,-.096,z),.009,'01_HELMET')
# Swept crown horns constructed as four-sided forged cross-section tapered plates, not cones.
for a in [(-.132,-.02),(-.086,.05),(0,.073),(.086,.05),(.132,-.02)]:
    xx,yy=a
    tapered_spike(f'Royal crown / forged lance {xx}',(xx,yy,2.125),(xx*1.45,yy+.025,2.43+.07*(1-abs(xx)/.14)),.027,steel,'01_HELMET')
for s in (-1,1):
    tapered_spike(f'Temple swept horn {s}',(s*.14,.037,2.075),(s*.255,.05,2.285),.044,steel,'01_HELMET')
path('Crown circlet gilt base',[(.161*sin(a*2*pi/44),-.002-.151*cos(a*2*pi/44),2.125) for a in range(45)],.014,gold,'01_HELMET')

# Layered gothic pauldrons with 3-part scalloped plates and perimeter beadwork.
for s in (-1,1):
    side='left' if s<0 else 'right'
    for tier in range(3):
        def pauldron(u,v,s=s,tier=tier):
            a=(u-.5)*pi*1.20
            # shell wraps shoulder, outer edge extends laterally; distinct scalloped endings.
            x=s*(.285+.07*tier+(.12+.027*tier)*cos(a))
            y=-.013+(.15+.018*tier)*sin(a)
            z=1.61-.07*tier + .115*cos(a)-.020*v+(.02+.02*tier)*sin(pi*v)
            return (x+s*.048*v,y+(.045*sin(u*2*pi))*v,z-.115*v)
        ob=surface(f'{side} pauldron / floating lames {tier}',pauldron,16,9,steel if tier else polished,'03_SHOULDERS',.015,1)
        pts=[pauldron(i/23,.98) for i in range(24)]
        path(f'{side} pauldron scalloped rim {tier}',pts,.015,edge,'03_SHOULDERS')
        for k in (4,12,20):
            p=pauldron(k/23,.80);rivet(f'{side} pauldron brass rivet {tier} {k}',p,.010,'03_SHOULDERS')
    tapered_spike(f'{side} backward shoulder spike',(s*.42,.08,1.70),(s*.56,.23,1.91),.028,steel,'03_SHOULDERS')

# Anatomically oriented tapered arms, open-joint elbows, vambrace shells, fingers.
for s in (-1,1):
    side='L' if s<0 else 'R'
    rings(f'{side} upper-arm plate',[(s*.38,.0,1.46,.120,.109),(s*.398,-.013,1.38,.115,.105),(s*.42,-.016,1.27,.088,.081)],steel,'04_ARMS',24)
    rings(f'{side} elbow floating cup',[(s*.42,-.018,1.26,.098,.095),(s*.432,-.018,1.18,.095,.089)],edge,'04_ARMS',24)
    rings(f'{side} forearm elongated tapered vambrace',[(s*.43,-.018,1.18,.092,.09),(s*.45,-.021,1.08,.093,.086),(s*.48,-.020,.98,.079,.071),(s*.5,-.018,.89,.064,.064)],polished,'04_ARMS',24)
    for k in range(4):
        zz=1.13-k*.066
        path(f'{side} vambrace steel engraved inlay {k}',[(s*(.44+.013*k+.071*cos(a*2*pi/16)), -.02-.076*sin(a*2*pi/16),zz) for a in range(17)],.007,gold,'04_ARMS')
    rings(f'{side} flared gauntlet cuff',[(s*.5,-.018,.94,.086,.086),(s*.52,-.028,.85,.071,.075)],steel,'05_GAUNTLETS',20)
    ellipsoid(f'{side} metacarpal articulated plate',(s*.53,-.04,.80),(.081,.071,.087),polished,'05_GAUNTLETS')
    for k in range(4):
        x=s*(.47+.035*k)
        rings(f'{side} separate steel finger {k}',[(x,-.085,.768,.016,.02),(x,-.095,.704,.014,.017)],edge,'05_GAUNTLETS',10)

# articulated waist plackart, tassets with 5 lames per side.
for k in range(3):
    z=1.05-.053*k
    def waist_lame(u,v,z=z,k=k):
        a=(u-.5)*pi*1.65
        return (.25*sin(a),-(.15+.015*k)*cos(a), z-.059*v-.014*sin(pi*u))
    surface(f'Waist nested lamellar belt {k}',waist_lame,26,5,steel,'06_WAIST',.012,1)
for s in (-1,1):
    for tier in range(5):
        z=.995-.085*tier
        def skirt(u,v,s=s,z=z,tier=tier):
            x=s*(.10+u*.157)+(u-.5)*.017
            y=-.103-.011*tier-.026*sin(pi*u)
            return (x,y,z-.084*v-.012*sin(pi*u)+.016*v*sin(pi*u))
        surface(f'Fauld tasset | {s} {tier}',skirt,8,5,steel if tier%2 else polished,'06_WAIST',.01,1)
        for x in (.13,.23):rivet(f'Waist tasset rivet {s} {tier} {x}',(s*x,-.14-.011*tier,z-.012),.007,'06_WAIST')

# Layered sabatons and knee cops in articulated greave / thigh shapes.
for s in (-1,1):
    side='L' if s<0 else 'R'
    rings(f'{side} thigh fluted cuisse',[(s*.142,0,.96,.128,.12),(s*.153,-.008,.83,.13,.114),(s*.16,-.008,.69,.108,.105)],polished,'07_LEGS',26)
    for k in range(3):
        path(f'{side} thigh raised flute {k}',[(s*(.14+(.04+k*.036)), -.111,.93),(s*(.145+(.04+k*.034)),-.11,.79),(s*(.15+(.04+k*.031)),-.098,.70)],.006,edge,'07_LEGS')
    ellipsoid(f'{side} elongated pointed poleyn | knee',(s*.16,-.098,.63),(.125,.06,.13),steel,'07_LEGS')
    tapered_spike(f'{side} narrow outward knee-wing',(s*.245,-.02,.64),(s*.34,-.02,.68),.045,polished,'07_LEGS')
    rings(f'{side} sculpted shin greave',[(s*.16,.012,.60,.10,.088),(s*.17,.014,.49,.108,.093),(s*.18,.02,.32,.078,.074),(s*.18,.018,.205,.075,.073)],polished,'07_LEGS',24)
    path(f'{side} centerline greave flute',[(s*.16,-.09,.58),(s*.17,-.105,.46),(s*.18,-.072,.23)],.012,edge,'07_LEGS')
    for j in range(4):
        z=.205-j*.038
        # sabaton toe elongated forwards -Y
        ellipsoid(f'{side} layered armored sabaton toe {j}',(s*.18,-.125-.040*j,z-.043),(.105,.16-.014*j,.045),steel if j%2 else edge,'08_BOOTS',20)
    rings(f'{side} ankle cuff segmented',[(s*.18,.012,.225,.082,.075),(s*.18,.008,.155,.091,.082)],steel,'08_BOOTS',24)

# Cape is actually a curved Blender surface with dozens of folds and irregular hem, separate object.
def cape(u,v):
    xx=(u-.5)*(.57+v*.75)
    pinch=sin(u*pi)*.055
    random_hem=.075*sin(u*23*pi)+.031*sin(u*51*pi+3)
    hem=v*v*max(0,random_hem)*.78
    z=1.79-1.61*v +hem + .037*sin(pi*u)*v
    y=.17+.20*v+.11*sin(u*9*pi)*v + .025*sin(u*27*pi)*v+.13*v*v
    return (xx,y+pinch,z)
surface('Torn scarlet warlord cape | individually editable cloth',cape,70,42,cloth,'09_CAPE',.009,0)
for s in (-1,1):
    pts=[cape(.5+s*(.48-.01*k/20),k/20) for k in range(21)]
    path(f'Cloak cord and rolled edge {s}',pts,.014,leather,'09_CAPE')

# Embossed front cloth apron with gothic heraldic motif.
surface('Frayed burgundy tabard apron',lambda u,v:((u-.5)*(.36+.015*v),-.225-.035*v,.99-.60*v+.022*sin(9*pi*u)*v**6),28,24,cloth,'06_WAIST',.009,0)
path('Tabard heraldic cross vertical',[(0,-.273,.92),(0,-.279,.57)],.014,gold,'06_WAIST')
path('Tabard heraldic cross horizontal',[(-.10,-.277,.82),(.1,-.277,.82)],.016,gold,'06_WAIST')
for s in (-1,1):
    path('Tabard heraldic wing '+str(s),[(0,-.28,.76),(s*.07,-.279,.70),(s*.12,-.273,.74)],.011,gold,'06_WAIST')

# Sword: constructed planar ground taper, edge grind, fuller, rich hilt. Suspended at right glove.
blade_verts=[]
for z,width,depth in [(.87,.051,.018),(.32,.048,.013),(-.10,.021,.006),(-.27,0,.001)]:
    for dx,dy in [(-1,0),(0,-1),(1,0),(0,1)]:
        blade_verts.append((.59+width*dx,-.112+depth*dy,z))
blade_faces=[]
for i in range(3):
    for k in range(4):blade_faces.append((i*4+k,i*4+(k+1)%4,(i+1)*4+(k+1)%4,(i+1)*4+k))
mesh('Hollow-ground long sword | real lozenge-section blade',blade_verts,blade_faces,edge,'10_SWORD',.003)
path('Sword fuller',[(.59,-.135,.83),(.59,-.13,.54),(.59,-.123,.32)],.013,steel,'10_SWORD')
path('Obsidian leather-wrapped hand grip',[(.59,-.11,.99),(.59,-.11,1.16)],.051,leather,'10_SWORD')
path('Decorative S-curve bronze crossguard',[(.39,-.11,.97),(.44,-.11,.945),(.52,-.11,.962),(.59,-.11,.96),(.68,-.11,.962),(.76,-.11,.945),(.79,-.11,.97)],.026,gold,'10_SWORD')
ellipsoid('Sword octagonal iron pommel',(.59,-.11,1.18),(.053,.053,.055),steel,'10_SWORD',16)

# Studio geometry is not part of the character. No environment/game assets.
base=mat('Studio basalt',(.05,.045,.048),.12,.92,35,.23)
path('Display turntable metal inlay',[(.82*cos(a*2*pi/72),.82*sin(a*2*pi/72),-.065) for a in range(73)],.025,gold,'11_STUDIO')
bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=.9,depth=.13,location=(0,0,-.09))
move(bpy.context.object,'11_STUDIO');bpy.context.object.name='Dark stone museum plinth';bpy.context.object.data.materials.append(base)

world=bpy.context.scene.world or bpy.data.worlds.new('Dark slate studio atmosphere');bpy.context.scene.world=world;world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.065,.064,.082,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.45

def area(name,loc,power,color,size):
    l=bpy.data.lights.new(name,'AREA');ob=bpy.data.objects.new(name,l);cols['11_STUDIO'].objects.link(ob);ob.location=loc
    l.energy=power;l.color=color;l.shape='DISK';l.size=size
    dir=Vector((0,0,1.20))-ob.location;ob.rotation_euler=dir.to_track_quat('-Z','Y').to_euler()
area('Soft cold overhead', (2,-4,5.4),900,(.62,.75,1),4.0)
area('Warm forge bounce',(-3,-2.1,3),1050,(1,.43,.22),3.0)
area('Silver outline rim',(0,3.6,4.4),1550,(.66,.75,1),2.6)

def cam(name,loc,target=(0,0,1.19),lens=65):
    c=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,c);cols['11_STUDIO'].objects.link(o)
    o.location=loc;rotation=(Vector(target)-o.location).to_track_quat('-Z','Y');o.rotation_euler=rotation.to_euler();c.lens=lens;return o
front=cam('Hero | front three-quarter', (3.35,-6.35,2.3),lens=58)
back=cam('Hero | back three-quarter',(-3.65,5.5,2.4),lens=58)
side=cam('Hero | accurate side', (6.1,-.8,2.05),lens=58)
face=cam('Helmet close-up', (1.55,-3.1,2.35),target=(0,0,2.02),lens=75)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT' if bpy.app.version >= (4, 2, 0) else 'BLENDER_EEVEE'
scene.render.resolution_x=1100;scene.render.resolution_y=1250;scene.render.resolution_percentage=85
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
# Handle version-compatible controls where possible.
if hasattr(scene,'render'):
    scene.render.image_settings.color_mode='RGBA'
for name,camera in [('01_front',front),('02_back',back),('03_side',side),('04_helmet',face)]:
    scene.camera=camera
    scene.render.filepath=os.path.join(OUT,name+'.png')
    bpy.ops.render.render(write_still=True)
# Save editable native source, with separate mesh objects organized by armor slot.
scene.camera=front
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'Crazy_Warlord_Blender_Test01.blend'))
with open(os.path.join(OUT,'MANIFEST.txt'),'w') as f:
    f.write('BLENDER APP VERSION: '+bpy.app.version_string+'\n')
    f.write('GENERATED USING bpy INSIDE BLENDER, not external geometry export.\n')
    for c in cols.values():
        f.write(f'{c.name}: {len(c.objects)} objects\n')
    f.write('No armature or skin weights yet. Surface sculpt and armature needed before production.\n')
print('BLENDER TEST FINISHED',bpy.app.version_string,OUT)