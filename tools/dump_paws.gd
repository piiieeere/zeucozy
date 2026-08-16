extends SceneTree

## Releve la structure du .glb du chat : surfaces, os porteurs, et boite
## englobante de chaque groupe d'os, en espace de REPOS.
##
## C'est la provenance des constantes `PAWS` de `cel_model.gd` — centres et
## demi-axes des quatre bouts de patte. Elles ne sont pas estimees, et si le
## modele est remodele elles doivent etre relevees a nouveau ici plutot que
## rectifiees a la main.
##
## Il repond aussi a la question qui a debloque les griffes : COMBIEN d'os
## porte une surface. `fourrure_blanche` en porte cinq, ce qui interdisait le
## `rest_undo` a deux entrees.
##
##     "C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" \
##         --headless --path . --script res://tools/dump_paws.gd

func _init() -> void:
	var packed: PackedScene = load("res://assets/models/player_cat.glb")
	var model := packed.instantiate()
	var mi := _find(model, "MeshInstance3D") as MeshInstance3D
	var skel := _find(model, "Skeleton3D") as Skeleton3D

	print("=== os du squelette ===")
	for b in skel.get_bone_count():
		print("  %2d %s" % [b, skel.get_bone_name(b)])

	var mesh := mi.mesh

	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		var mat_name := mat.resource_name if mat else "<sans nom>"
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]

		if bones.is_empty():
			print("\n--- surface %d  %s  (%d sommets, SANS skin)" % [s, mat_name, verts.size()])
			continue

		var per_bone := {}  # id -> [count, AABB]
		# Nombre d'influences par sommet : 4 chez Godot, mais on le deduit.
		var stride := int(bones.size() / verts.size())

		for v in verts.size():
			var best := -1
			var best_w := -1.0

			for k in stride:
				var w := weights[v * stride + k]

				if w > best_w:
					best_w = w
					best = bones[v * stride + k]

			if not per_bone.has(best):
				per_bone[best] = [0, AABB(verts[v], Vector3.ZERO), 0.0]

			per_bone[best][0] += 1
			per_bone[best][1] = per_bone[best][1].expand(verts[v])
			per_bone[best][2] = maxf(per_bone[best][2], best_w)

		print("\n--- surface %d  %s  (%d sommets, %d os, %d influences/sommet)"
				% [s, mat_name, verts.size(), per_bone.size(), stride])

		for id in per_bone:
			var e = per_bone[id]
			var box: AABB = e[1]
			print("    os %2d %-12s %4d sommets  centre (%.3f, %.3f, %.3f)  taille (%.3f, %.3f, %.3f)  poids max %.3f"
					% [id, skel.get_bone_name(id), e[0],
					box.get_center().x, box.get_center().y, box.get_center().z,
					box.size.x, box.size.y, box.size.z, e[2]])

	quit()


func _find(node: Node, type_name: StringName) -> Node:
	if node.is_class(type_name):
		return node

	for child in node.get_children():
		var found := _find(child, type_name)

		if found != null:
			return found

	return null
