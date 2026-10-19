bl_info = {
    "name": "Crazy: AI Armor from Reference",
    "author": "Crazy project",
    "version": (0, 1, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > Crazy AI",
    "description": "Hunyuan3D-generated 3D mesh into separate editable Blender armor collections",
    "category": "Import-Export",
}

import bpy
import os
import json
import base64
import urllib.request
import urllib.error
import tempfile
from bpy.props import EnumProperty, StringProperty, PointerProperty

ARMOR_SLOTS = [
    ("BODY", "Body", "Anatomical rig base (prefer imported, rigged CC0 source)"),
    ("HELMET", "Helmet", "Crowned gothic black helmet"),
    ("CUIRASS", "Cuirass", "Layered chest plate"),
    ("PAULDRONS", "Pauldrons", "Separate shoulder armor"),
    ("ARMS", "Arms", "Vambraces and gauntlets"),
    ("LEGS", "Legs", "Cuisses, knee plates and greaves"),
    ("BOOTS", "Boots", "Armored sabatons"),
    ("CAPE", "Cape", "Tattered dark red cloth"),
    ("SWORD", "Sword", "Dark fantasy greatsword"),
]
COLLECTION_ROOT = "CRAZY_AI_WARLORD"

class CRAZY_AI_Properties(bpy.types.PropertyGroup):
    reference: StringProperty(name="Reference image", subtype="FILE_PATH", description="Single clean image of this specific equipment piece")
    slot: EnumProperty(name="Equipment slot", items=ARMOR_SLOTS, default="HELMET")

def get_collection(name, parent):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        parent.children.link(collection)
    return collection

class CRAZY_AI_OT_generate(bpy.types.Operator):
    bl_idname = "crazy_ai.generate_armor"
    bl_label = "Generate real 3D mesh"
    bl_description = "Calls an existing local Hunyuan3D shape server, imports real generated GLB meshes into an independent Blender collection"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        config = context.scene.crazy_ai_config
        source = bpy.path.abspath(config.reference)
        if not os.path.isfile(source):
            self.report({"ERROR"}, "Choose a real reference image")
            return {"CANCELLED"}
        if os.path.splitext(source)[1].lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            self.report({"ERROR"}, "Image must be PNG/JPG/WebP")
            return {"CANCELLED"}

        with open(source, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("ascii")
        req = urllib.request.Request(
            "http://127.0.0.1:8080/generate",
            data=json.dumps({"image": image_b64}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=1200) as response:
                payload = response.read()
                content_type = response.headers.get("Content-Type", "")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            self.report({"ERROR"}, "Local Hunyuan3D server unavailable: " + str(e)[:150])
            return {"CANCELLED"}

        # A real glTF binary starts with "glTF" magic. Never substitute primitives.
        if len(payload) < 100 or payload[:4] != b"glTF":
            self.report({"ERROR"}, "Server did not return a valid binary GLB. " + str(content_type)[:90])
            return {"CANCELLED"}

        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as f:
                temp_path = f.name
                f.write(payload)
            selected_before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=temp_path)
            imported = [o for o in bpy.data.objects if o not in selected_before]
            meshes = [o for o in imported if o.type == "MESH"]
            if not meshes:
                raise RuntimeError("Imported GLB contains no meshes")
            root = get_collection(COLLECTION_ROOT, context.scene.collection)
            group = get_collection("AI_" + config.slot, root)
            for ob in imported:
                for coll in list(ob.users_collection):
                    coll.objects.unlink(ob)
                group.objects.link(ob)
                ob["crazy_ai_slot"] = config.slot
                ob["crazy_ai_source"] = os.path.basename(source)
            # Do NOT auto-rig; weights must be verified before assigning animation.
            self.report({"INFO"}, "Generated " + str(len(meshes)) + " real editable mesh(es) in " + group.name)
        except Exception as e:
            self.report({"ERROR"}, "Import failed: " + str(e)[:180])
            return {"CANCELLED"}
        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)
        return {"FINISHED"}

class CRAZY_AI_PT_panel(bpy.types.Panel):
    bl_label = "Crazy: AI Armor"
    bl_idname = "CRAZY_AI_PT_panel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Crazy AI"
    def draw(self, context):
        layout = self.layout
        c = context.scene.crazy_ai_config
        layout.label(text="Hunyuan3D: 127.0.0.1:8080")
        layout.prop(c, "slot")
        layout.prop(c, "reference")
        layout.operator("crazy_ai.generate_armor", icon="MESH_DATA")
        layout.label(text="Model only; requires rigging and QA")

classes = (CRAZY_AI_Properties, CRAZY_AI_OT_generate, CRAZY_AI_PT_panel)
def register():
    for klass in classes:
        bpy.utils.register_class(klass)
    bpy.types.Scene.crazy_ai_config = PointerProperty(type=CRAZY_AI_Properties)
def unregister():
    del bpy.types.Scene.crazy_ai_config
    for klass in reversed(classes):
        bpy.utils.unregister_class(klass)
if __name__ == "__main__":
    register()
