# Imagem do item guincho_portatil: motor do jogo (prop_bison_winch) + gancho do jogo (prop_rope_hook_01)
# ligados por um cabo de aço; luz de estúdio, fundo transparente. Saída: 100x100 (inventário) e prévia 512.
import bpy, sys, os, math, addon_utils
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
PASTA, OUT = argv[0], argv[1]
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable('bl_ext.user_default.sollumz', default_set=True)

def importar(nome):
    antes = set(bpy.data.objects)
    bpy.ops.sollumz.import_assets(directory=PASTA, files=[{'name': nome + '.ydr'}])
    novos = [o for o in bpy.data.objects if o not in antes]
    raiz = next(o for o in novos if o.parent is None)
    for o in novos:
        if o.type == 'MESH' and getattr(o, 'sollum_type', '') != 'sollumz_drawable_model':
            o.hide_render = True
    return raiz, [o for o in novos if o.type == 'MESH' and not o.hide_render]

motor, malhas_motor = importar('prop_bison_winch')
gancho, malhas_gancho = importar('prop_rope_hook_01')

def caixa(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))

gmn, gmx = caixa(malhas_gancho)
print('[render] gancho caixa', tuple(round(v, 3) for v in gmn), tuple(round(v, 3) for v in gmx))

# gancho na frente do motor, deitado no chão, um pouco para o lado
gancho.rotation_euler = (math.radians(90), 0.0, math.radians(-25))
bpy.context.view_layer.update()
gmn, gmx = caixa(malhas_gancho)
alvo = Vector((0.42, 0.78, -0.206))  # onde fica a base do gancho (z = chão do motor)
gancho.location += alvo - Vector(((gmn.x + gmx.x) / 2, (gmn.y + gmx.y) / 2, gmn.z))
bpy.context.view_layer.update()
gmn, gmx = caixa(malhas_gancho)

# ponta do gancho mais perto do motor = olhal onde o cabo prende
# o gancho pendurado tem o olhal no topo (z local ~0.127): o cabo prende ali
olhal = gancho.matrix_world @ Vector((0.0, 0.0, 0.105))
saida = Vector((0.12, 0.12, 0.17))  # topo do tambor, puxando para a frente
borda = Vector((0.2, 0.47, 0.215))  # passa por cima da borda da base

curva = bpy.data.curves.new('cabo', 'CURVE')
curva.dimensions = '3D'
curva.bevel_depth = 0.011
curva.bevel_resolution = 4
sp = curva.splines.new('BEZIER')
sp.bezier_points.add(2)
for pt, co in zip(sp.bezier_points, (saida, borda, olhal)):
    pt.co = co
    pt.handle_left_type = pt.handle_right_type = 'AUTO'
cabo = bpy.data.objects.new('cabo', curva)
bpy.context.scene.collection.objects.link(cabo)
aco = bpy.data.materials.new('aco')
aco.use_nodes = True
bsdf = aco.node_tree.nodes['Principled BSDF']
bsdf.inputs['Base Color'].default_value = (0.55, 0.57, 0.6, 1)
bsdf.inputs['Metallic'].default_value = 1.0
bsdf.inputs['Roughness'].default_value = 0.35
curva.materials.append(aco)

# gancho: a textura dele fica em outro dicionário; aço pintado de vermelho, como gancho de guincho
pintado = bpy.data.materials.new('gancho_pintado')
pintado.use_nodes = True
pb = pintado.node_tree.nodes['Principled BSDF']
pb.inputs['Base Color'].default_value = (0.16, 0.02, 0.015, 1)
pb.inputs['Metallic'].default_value = 0.8
pb.inputs['Roughness'].default_value = 0.55
for o in malhas_gancho:
    o.data.materials.clear()
    o.data.materials.append(pintado)

todos = malhas_motor + malhas_gancho
mn, mx = caixa(todos)
centro = (mn + mx) / 2
raio = (mx - mn).length / 2
print('[render] cena', tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx))

cena = bpy.context.scene
cena.render.engine = 'BLENDER_EEVEE'
cena.render.film_transparent = True
cena.render.image_settings.file_format = 'PNG'
cena.render.image_settings.color_mode = 'RGBA'
cena.view_settings.view_transform = 'Standard'
cena.view_settings.exposure = 0.6
mundo = bpy.data.worlds.new('mundo')
cena.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes['Background'].inputs[1].default_value = 1.2

def luz(nome, energia, pos, tamanho):
    d = bpy.data.lights.new(nome, 'AREA')
    d.energy, d.size = energia, tamanho
    o = bpy.data.objects.new(nome, d)
    cena.collection.objects.link(o)
    o.location = pos
    o.rotation_euler = (centro - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()

luz('chave', 900 * raio * raio, centro + Vector((raio * 2.5, raio * 3, raio * 3.5)), raio * 3)
luz('preenche', 400 * raio * raio, centro + Vector((-raio * 3, raio * 2, raio * 2)), raio * 3)
luz('contra', 600 * raio * raio, centro + Vector((-raio, -raio * 4, raio * 3)), raio * 2)

camd = bpy.data.cameras.new('cam')
cam = bpy.data.objects.new('cam', camd)
cena.collection.objects.link(cam)
cena.camera = cam
ang, dist = math.radians(30), raio * 4
cam.location = centro + Vector((math.sin(ang) * dist, math.cos(ang) * dist, dist * 0.6))
cam.rotation_euler = (centro - cam.location).to_track_quat('-Z', 'Y').to_euler()
camd.lens = 50
cena.render.resolution_x = cena.render.resolution_y = 100
pts = [c for o in todos for v in o.bound_box for c in (o.matrix_world @ Vector(v))]
co, _ = cam.camera_fit_coords(bpy.context.evaluated_depsgraph_get(), pts)
cam.location = co
camd.lens *= 0.9

for nome, res in (('previa2_512', 512), ('guincho_portatil', 100)):
    cena.render.resolution_x = cena.render.resolution_y = res
    cena.render.filepath = os.path.join(OUT, nome + '.png')
    bpy.ops.render.render(write_still=True)
    print('[render] salvo', cena.render.filepath)
