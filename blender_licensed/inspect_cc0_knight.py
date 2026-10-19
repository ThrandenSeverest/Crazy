"""Inspect an existing CC0 human+armor .blend INSIDE Blender. No primitive meshes built."""
import bpy, os, json
from mathutils import Vector
src=os.environ["CRAZY_SOURCE_BLEND"]
out=os.environ.get("CRAZY_OUT","build/cc0-source-review")
os.makedirs(out,exist_ok=True)
assert os.path.isfile(src) and os.path.getsize(src)>300000, "Source .blend missing"
bpy.ops.wm.open_mainfile(filepath=src)
meshes=[o for o in bpy.data.objects if o.type=="MESH"]
rigs=[o for o in bpy.data.objects if o.type=="ARMATURE"]
vertices=sum(len(o.data.vertices) for o in meshes)
assert vertices>9000, f"Real geometry missing: {vertices}"
report={"source":"Knight by crownjoshua (CC0)","mesh_count":len(meshes),"vertices":vertices,"rigs":[{"name":a.name,"bones":len(a.data.bones)} for a in rigs],"objects":[{"name":m.name,"verts":len(m.data.vertices),"faces":len(m.data.polygons),"materials":[v.name for v in m.data.materials if v]} for m in meshes]}
with open(os.path.join(out,"model_inventory.json"),"w",encoding="utf-8") as f:json.dump(report,f,ensure_ascii=False,indent=2)
print("REAL_GEOMETRY_REPORT",json.dumps({"meshes":len(meshes),"rigs":len(rigs),"vertices":vertices}),flush=True)
for o in list(bpy.data.objects):
    if o.type in ("LIGHT","CAMERA"):bpy.data.objects.remove(o,do_unlink=True)
pts=[ob.matrix_world@Vector(c) for ob in meshes for c in ob.bound_box if not ob.hide_render]
if not pts:pts=[ob.matrix_world@Vector(c) for ob in meshes for c in ob.bound_box]
bounds_lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
bounds_hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
ctr=(bounds_hi+bounds_lo)/2
dims=bounds_hi-bounds_lo
dist=max(3.0,dims.length*1.2)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=18
scene.cycles.use_denoising=False
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=760;scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
bpy.ops.object.camera_add()
cam=bpy.context.object;cam.name="CRAZY_Inspect_Camera";scene.camera=cam
cam.data.type="ORTHO";cam.data.ortho_scale=max(dims.x,dims.y,dims.z)*1.6
bpy.ops.object.light_add(type="AREA")
key=bpy.context.object;key.location=ctr+Vector((dist,-dist,dist))
key.data.energy=1200;key.data.size=dist
bpy.ops.object.light_add(type="AREA")
fill=bpy.context.object;fill.location=ctr+Vector((-dist,dist,dist))
fill.data.energy=650;fill.data.size=dist
for name,axis in [("front",(0,-1,0.2)),("side",(1,0,0.2)),("back",(0,1,0.2))]:
    cam.location=ctr+Vector(axis).normalized()*dist
    cam.rotation_euler=(ctr-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=os.path.join(out,name+".png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.join(out,"Crazy_Knight_Source_Inspection.blend")))
print("REAL_BLENDER_IMPORT_AND_RENDER_DONE",flush=True)
