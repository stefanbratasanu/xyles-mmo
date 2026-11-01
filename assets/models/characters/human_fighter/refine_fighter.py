import bpy,bmesh,math
from pathlib import Path
HERE = Path(__file__).resolve().parent
from mathutils import Vector
from mathutils.bvhtree import BVHTree
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(HERE / 'fighter_rigged.glb'))
mesh=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices));bpy.context.view_layer.objects.active=mesh;mesh.select_set(True)
orig=mesh.data.copy();orig.calc_loop_triangles();coords=[v.co.copy() for v in orig.vertices];tris=[tuple(t.vertices) for t in orig.loop_triangles];bvh=BVHTree.FromPolygons(coords,tris,all_triangles=True)
uv_orig=orig.uv_layers.active.data; original_weights=[{g.group:g.weight for g in v.groups} for v in orig.vertices]
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.symmetrize(direction='POSITIVE_X',threshold=.0001);bpy.ops.object.mode_set(mode='OBJECT')
print('symmetric',len(mesh.data.vertices),len(mesh.data.polygons),flush=True)
def bary(p,a,b,c):
 v0=b-a;v1=c-a;v2=p-a;d00=v0.dot(v0);d01=v0.dot(v1);d11=v1.dot(v1);d20=v2.dot(v0);d21=v2.dot(v1);den=d00*d11-d01*d01
 if abs(den)<1e-20:return (1.,0.,0.)
 v=(d11*d20-d01*d21)/den;w=(d00*d21-d01*d20)/den;return (1.-v-w,v,w)
# Preserve the original un-tattooed side's body texture using a side-specific surface lookup.
left_tris=[];left_src=[]
for tri in orig.loop_triangles:
 if sum(coords[v].x for v in tri.vertices)/3 < 0:
  left_tris.append(tuple(tri.vertices));left_src.append(tri)
left_bvh=BVHTree.FromPolygons(coords,left_tris,all_triangles=True)
uv=mesh.data.uv_layers.active.data
for poly in mesh.data.polygons:
 if poly.center.z>=.63 or poly.center.z<=.25 or poly.center.x>=-.12:continue
 loc,_,ti,dist=left_bvh.find_nearest(poly.center)
 if ti is None:continue
 tri=left_src[ti];a,b,c=[coords[v] for v in tri.vertices]
 for li in poly.loop_indices:
  pos=mesh.data.vertices[mesh.data.loops[li].vertex_index].co
  w=bary(pos,a,b,c)
  uv[li].uv=sum((uv_orig[tri.loops[j]].uv * w[j] for j in range(3)),Vector((0,0)))
print('body UV restored',flush=True)
# Transfer the original rig weights to corresponding points; soften the seam at the groin.
for v in mesh.data.vertices:
 loc,_,ti,_=bvh.find_nearest(v.co)
 if ti is None:continue
 tri=orig.loop_triangles[ti];a,b,c=[coords[k] for k in tri.vertices];w=bary(loc,a,b,c);weights={}
 for k,vi in enumerate(tri.vertices):
  for gid,val in original_weights[vi].items():weights[gid]=weights.get(gid,0)+val*w[k]
 group_hips=mesh.vertex_groups.get('Hips');left=mesh.vertex_groups.get('LeftUpLeg');right=mesh.vertex_groups.get('RightUpLeg')
 if group_hips and left and right and -.20<v.co.z<.18 and abs(v.co.x)<.13:
  central=max(0.,1-abs(v.co.x)/.13);vertical=min(1.,max(0.,(v.co.z+.20)/.25));factor=central*vertical
  current=weights.get(group_hips.index,0);desired=max(current,.65*factor);total=weights.get(left.index,0)+weights.get(right.index,0)+current
  if total>0 and desired>current:
   desired=min(desired,total);scale=(total-desired)/max(1e-8,total-current)
   weights[left.index]=weights.get(left.index,0)*scale;weights[right.index]=weights.get(right.index,0)*scale;weights[group_hips.index]=desired
 for g in v.groups[:]:mesh.vertex_groups[g.group].remove([v.index])
 for gid,val in weights.items():
  if val>0.0001:mesh.vertex_groups[gid].add([v.index],val,'REPLACE')
print('weights transferred',flush=True)
bpy.ops.export_scene.gltf(filepath=str(HERE / 'fighter_refined.glb'),export_format='GLB',export_animations=False)
