import bpy,bmesh,math,numpy as np
import json,struct
from mathutils.kdtree import KDTree
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[3];assets=root/'assets/models/characters/human_fighter';out=root/'logs/face_rebuild'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(assets/'user_tweaked_df18cad1/rigged_pbr.glb'))
body=max((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices));body.name='FighterBody';arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
# Preserve source neck samples before any cuts for a color-matched transition.
kd=KDTree(len(body.data.vertices))
for v in body.data.vertices:kd.insert(v.co,v.index)
kd.balance()
source_weights={v.index:{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in body.data.vertices}
def uv_by_vertex(obj):
 uv={}
 for loop in obj.data.loops:uv[loop.vertex_index]=obj.data.uv_layers.active.data[loop.index].uv.copy()
 return uv
def color_sampler(obj):
 mat=obj.data.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 im=bs.inputs['Base Color'].links[0].from_node.image
 w,h=im.size;px=np.empty(w*h*4,dtype=np.float32);im.pixels.foreach_get(px);px=px.reshape((h,w,4))
 def sample(uv):return px[int(uv.y*h)%h,int(uv.x*w)%w,:3].copy()
 return sample
bodyuv=uv_by_vertex(body);body_sample=color_sampler(body)
old=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(assets/'head_revision/head_source.glb'))
head=max((o for o in bpy.context.scene.objects if o.type=='MESH' and o not in old),key=lambda o:len(o.data.vertices));head.name='ReplacementHead'
for v in head.data.vertices:v.co = head.matrix_world@v.co*.17+Vector((0,.015,.788))
head.matrix_world=body.matrix_world.copy()
body_z=.68;head_z=.681
for obj,z,remove_above in [(body,body_z,True),(head,head_z,False)]:
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=(0,0,z),plane_no=(0,0,1),clear_outer=remove_above,clear_inner=not remove_above)
 bm.to_mesh(obj.data);bm.free()
# Blend both atlases toward a shared neck color at the join. Store the target
# RGB and blend amount separately, rather than multiplying incompatible colors.
huv=uv_by_vertex(head);head_sample=color_sampler(head)
neck_samples=[body_sample(bodyuv[v.index]) for v in body.data.vertices if abs(v.co.z-body_z)<.012]
neck_color=np.median(np.array(neck_samples),axis=0)
neck_color=np.where(neck_color<=.04045,neck_color/12.92,((neck_color+.055)/1.055)**2.4)
for obj in [body,head]:
 for attribute in list(obj.data.color_attributes):obj.data.color_attributes.remove(attribute)
 colors=obj.data.color_attributes.new(name='NeckBlend',type='FLOAT_COLOR',domain='POINT')
 for v in obj.data.vertices:
  distance=abs(v.co.z-(body_z+head_z)*.5)
  t=max(0,min(1,(.06-distance)/.045));t=t*t*(3-2*t)
  colors.data[v.index].color=(*neck_color,t)
print('NECK COLOR',neck_color,flush=True)
# Retain source body modifiers; replace donor skin with current Head/Neck groups.
head.vertex_groups.clear()
groups={b.name:head.vertex_groups.new(name=b.name) for b in arm.data.bones}
for v in head.data.vertices:
 t=max(0,min(1,(v.co.z-.681)/.085));t=t*t*(3-2*t)
 co,idx,dist=kd.find(v.co)
 weights={name:weight*(1-t) for name,weight in source_weights[idx].items()}
 weights['Head']=weights.get('Head',0)+t
 for name,weight in weights.items():
  if weight>.00001 and name in groups:groups[name].add([v.index],weight,'REPLACE')
for mod in list(head.modifiers):head.modifiers.remove(mod)
head.parent=None;head.matrix_world=body.matrix_world.copy()
# Keep two material atlases. Skin material parameters comparable to current player.
for obj in [head,body]:
 for mat in obj.data.materials:
  if not mat or not mat.use_nodes:continue
  bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if bs:
   for socket in ['Normal','Roughness','Metallic']:
    for l in list(bs.inputs[socket].links):mat.node_tree.links.remove(l)
   bs.inputs['Roughness'].default_value=.82;bs.inputs['Metallic'].default_value=0
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);head.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
# Join the two neck boundaries with a small geometry collar. Preserve UVs on all original faces.
bm=bmesh.new();bm.from_mesh(body.data)
# Imported GLTF uses split UV edges; weld only neck boundary vertices.
neck=[v for v in bm.verts if abs(v.co.z-body_z)<.00001 or abs(v.co.z-head_z)<.00001]
bmesh.ops.remove_doubles(bm,verts=neck,dist=.00001)
boundary=[e for e in bm.edges if e.is_boundary and all(abs(v.co.z-body_z)<.00001 or abs(v.co.z-head_z)<.00001 for v in e.verts)]
print('BRIDGE BOUNDARIES',len(boundary),flush=True)
# Stitch unequal circular neck boundaries explicitly; bridge_loops can silently return no faces.
center=Vector((0,.018,0))
def angle(v):return math.atan2(v.co.y-center.y,v.co.x-center.x)%(2*math.pi)
rings=[sorted([v for v in bm.verts if abs(v.co.z-z)<.00001],key=angle) for z in [body_z,head_z]]
low,high=rings
# Fit donor neck circumference to the body; taper correction out before jaw.
def target(theta):
 for i,v in enumerate(low):
  w=low[(i+1)%len(low)];a=angle(v);b=angle(w)
  if b<=a:b+=2*math.pi
  t=theta if theta>=a else theta+2*math.pi
  if a<=t<=b:return v.co.lerp(w.co,(t-a)/(b-a))
 return low[0].co.copy()
corrections=[(angle(v),target(angle(v))-v.co) for v in high]
for v in bm.verts:
 if v.co.z>=head_z-.00001 and v.co.z<.74:
  theta=angle(v);delta=min(corrections,key=lambda x:abs((x[0]-theta+math.pi)%(2*math.pi)-math.pi))[1]
  t=max(0,min(1,(.74-v.co.z)/(.74-head_z)));t=t*t*(3-2*t)
  v.co.x+=delta.x*t;v.co.y+=delta.y*t
faces=[];i=j=0
while i<len(low) or j<len(high):
 ni=angle(low[(i+1)%len(low)]) if i+1<len(low) else 2*math.pi+angle(low[0])
 nj=angle(high[(j+1)%len(high)]) if j+1<len(high) else 2*math.pi+angle(high[0])
 if i<len(low) and (j>=len(high) or ni<=nj):
  verts=(low[i%len(low)],low[(i+1)%len(low)],high[j%len(high)]);i+=1
 else:
  verts=(low[i%len(low)],high[(j+1)%len(high)],high[j%len(high)]);j+=1
 try:faces.append(bm.faces.new(verts))
 except ValueError:pass
result={'faces':faces}
print('STITCH',len(low),len(high),len(faces),flush=True)
# The collar uses the BODY material. Never interpolate donor-head UVs into
# that atlas: they refer to entirely different skin/shorts texels.
uv=bm.loops.layers.uv.active
for face in faces:
 face.smooth=True
 face.material_index=0
 for loop in face.loops:
  sample=loop.vert.co.copy();sample.z=body_z
  co,idx,dist=kd.find(sample)
  loop[uv].uv=bodyuv[idx]
bmesh.ops.recalc_face_normals(bm,faces=result.get('faces',[]));bm.to_mesh(body.data);bm.free()
# Keep the original current armature as the only skin driver.

for mod in body.modifiers:
 if mod.type=='ARMATURE':mod.object=arm
body.parent=arm
# Match the runtime shader: shared target color with a smooth local alpha mask.
for mat in body.data.materials:
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 source=bs.inputs['Base Color'].links[0].from_socket
 attr=mat.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='NeckBlend'
 mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX'
 mat.node_tree.links.new(attr.outputs['Alpha'],mix.inputs[0])
 mat.node_tree.links.new(source,mix.inputs[1]);mat.node_tree.links.new(attr.outputs['Color'],mix.inputs[2]);mat.node_tree.links.new(mix.outputs[0],bs.inputs['Base Color'])
# Weld UV split vertices while preserving per-corner UV coordinates.
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
# Relax the cut-ring tangent discontinuity on both sides of the welded join.
neck_band=[v for v in bm.verts if .63<v.co.z<.735]
for iteration in range(100):
 updates=[]
 for v in neck_band:
  neighbors=[e.other_vert(v) for e in v.link_edges]
  if not neighbors:continue
  mean=sum((n.co for n in neighbors),Vector())/len(neighbors)
  mask=max(0,1-abs(v.co.z-.681)/.052)
  updates.append((v,v.co.lerp(mean,.45*mask)))
 for v,co in updates:v.co=co
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.normal_update();bm.to_mesh(body.data);bm.free()
body.data.normals_split_custom_set([(0,0,0)]*len(body.data.loops))
body.data.color_attributes.active_color_index=0
# Build each selected combination as one authored deformation on this topology.
import sys
sys.dont_write_bytecode = True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from physique_shapes import build as build_physiques
build_physiques(body,arm)
# Save editable proof and export only current mesh/rig.
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);arm.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'head_swap.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'head_swap.glb'),use_selection=True,export_format='GLB',export_animations=False,export_all_vertex_colors=True)
# The exporter emits a white COLOR_0 when a custom Mix node is present,
# followed by our actual named attribute as COLOR_1. Godot reads COLOR_0.
glb_path=out/'head_swap.glb'
data=glb_path.read_bytes();json_length=struct.unpack_from('<I',data,12)[0]
document=json.loads(data[20:20+json_length]);tail=data[20+json_length:]
for mesh in document.get('meshes',[]):
 for primitive in mesh['primitives']:
  attributes=primitive['attributes']
  if 'COLOR_1' in attributes:attributes['COLOR_0']=attributes.pop('COLOR_1')
encoded=json.dumps(document,separators=(',',':')).encode('utf-8');encoded+=b' '*((-len(encoded))%4)
glb_path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(tail))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+tail)
# Neutral textured review.
points=[body.matrix_world@Vector(v) for v in body.bound_box];hi=max(p.z for p in points);center=Vector((0,0,hi-.2))
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=.5;bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=center+Vector((-2,-3,3)));bpy.context.object.data.energy=350;bpy.context.object.data.size=4
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=24;sc.render.resolution_x=640;sc.render.resolution_y=700;sc.world.color=(.2,.2,.2)
for view,offset in [('front',(0,-3,0)),('left',(3,0,0)),('right',(-3,0,0))]:
 cam.location=center+Vector(offset);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();sc.render.filepath=str(out/f'swap_{view}.png');bpy.ops.render.render(write_still=True)

