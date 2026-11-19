extends SceneTree


func _set_owners_preserving_instances(node: Node, root_owner: Node) -> void:
	for child in node.get_children():
		child.owner = root_owner
		# Do NOT descend into instanced .glb scenes — keep them as clean external scene instances!
		if child.scene_file_path.is_empty():
			_set_owners_preserving_instances(child, root_owner)


func _init() -> void:
	print("Baking editable res://scenes/arena.tscn and res://scenes/main.tscn...")

	var arena := ArenaBuilder.new()
	arena.name = "Arena"
	root.add_child(arena)
	arena.build_arena(true)
	_set_owners_preserving_instances(arena, arena)

	var arena_packed := PackedScene.new()
	var err := arena_packed.pack(arena)
	if err != OK:
		push_error("Failed to pack arena.tscn: " + str(err))
		quit(1)
		return

	err = ResourceSaver.save(arena_packed, "res://scenes/arena.tscn")
	if err != OK:
		push_error("Failed to save arena.tscn: " + str(err))
		quit(1)
		return
	print("Saved res://scenes/arena.tscn successfully!")

	# Now rebuild main.tscn with Arena cleanly instanced inside Main!
	arena.queue_free()

	var main_root := Node3D.new()
	main_root.name = "Main"
	main_root.set_script(load("res://scripts/game_manager.gd"))
	root.add_child(main_root)

	var arena_inst: Node = load("res://scenes/arena.tscn").instantiate()
	arena_inst.name = "Arena"
	main_root.add_child(arena_inst)
	arena_inst.owner = main_root

	var main_packed := PackedScene.new()
	err = main_packed.pack(main_root)
	if err != OK:
		push_error("Failed to pack main.tscn: " + str(err))
		quit(1)
		return

	err = ResourceSaver.save(main_packed, "res://scenes/main.tscn")
	if err != OK:
		push_error("Failed to save main.tscn: " + str(err))
		quit(1)
		return

	print("Saved res://scenes/main.tscn with instanced Arena successfully!")
	quit(0)
