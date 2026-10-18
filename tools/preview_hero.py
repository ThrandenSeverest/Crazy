#!/usr/bin/env python3
"""Software preview of hard-surface generated GLBs, requires numpy trimesh Pillow."""
from pathlib import Path
import math
import trimesh
import numpy as np
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parent.parent
files=sorted((root/'assets/hero').glob('*.glb'))
meshes=[]
for file in files:
    scene=trimesh.load(file,force='scene')
    for geo in scene.geometry.values():
        if len(geo.faces):
            color=np.array(geo.visual.material.baseColorFactor[:3],dtype=float)
            meshes.append((geo.vertices,geo.faces,color))

def render(angle,name):
    w,h=720,1030
    img=Image.new('RGB',(w,h),(40,38,44))
    dr=ImageDraw.Draw(img)
    a=math.radians(angle)
    rot=np.array([[math.cos(a),0,math.sin(a)],[0,1,0],[-math.sin(a),0,math.cos(a)]])
    light=np.array([.52,.67,.55]); light/=np.linalg.norm(light)
    faces=[]
    for v,f,col in meshes:
        pts=v@rot.T
        tri=pts[f]
        n=np.cross(tri[:,1,:]-tri[:,0,:],tri[:,2,:]-tri[:,0,:])
        nn=np.linalg.norm(n,axis=1)
        n=n / np.maximum(nn[:,None],1e-8)
        shade=.34+.85*np.clip(np.abs(n@light),0,1)
        xy=np.stack([w/2+tri[:,:,0]*375,h-102-tri[:,:,1]*375],axis=-1)
        depth=np.mean(tri[:,:,2],axis=1)
        # painter algorithm
        for i in range(len(f)):
            rgb=tuple(int(min(255,max(0,x*shade[i]))) for x in col)
            faces.append((depth[i],xy[i],rgb))
    faces.sort(key=lambda row:row[0])
    for _,xy,rgb in faces:
        dr.polygon([tuple(p) for p in xy],fill=rgb)
    dr.text((25,20),f'CRAZY / HERO CONSTRUCTION • {name}',fill=(223,214,190))
    dr.text((25,48),'3D GLB geometry alpha / not final reference quality',fill=(156,151,145))
    return img
out=Image.new('RGB',(2160,1030),(40,38,44))
for i,(a,name) in enumerate([(0,'front'),(180,'back'),(75,'side')]):out.paste(render(a,name),(i*720,0))
out.save(root/'hero_model_preview.png')
print(root/'hero_model_preview.png')