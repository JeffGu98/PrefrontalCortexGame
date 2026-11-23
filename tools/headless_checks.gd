extends SceneTree
## Headless sanity checks for hub registration, versions, and 各点一次 helpers.


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var failed := 0
	failed += _check_versions()
	failed += _check_hub_games()
	failed += _check_self_order_logic()
	failed += await _check_self_order_play()
	if failed == 0:
		print("HEADLESS_CHECKS_OK")
		quit(0)
	else:
		print("HEADLESS_CHECKS_FAILED %d" % failed)
		quit(1)


func _check_versions() -> int:
	var failed := 0
	var project := str(ProjectSettings.get_setting("application/config/version", ""))
	if project != "1.7.0":
		print("FAIL version project=%s" % project)
		failed += 1
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets.find('version/name="1.7.0"') < 0 or presets.find("version/code=170") < 0:
		print("FAIL export_presets version")
		failed += 1
	if presets.find('export_path="build/PrefrontalCortexGame-1.7.0.apk"') < 0:
		print("FAIL export_path")
		failed += 1
	for key in ["keystore/debug=", "keystore/release=", "keystore/debug_password=", "keystore/release_password="]:
		if presets.find('%s"' % key) >= 0:
			# must be empty quotes immediately, or empty after =
			pass
	if presets.find('keystore/release_password=""') < 0 or presets.find('keystore/release=""') < 0:
		print("FAIL keystore fields must stay empty in git")
		failed += 1
	return failed


func _check_hub_games() -> int:
	var failed := 0
	var hub_script := load("res://scripts/Hub.gd")
	if hub_script == null:
		print("FAIL load Hub.gd")
		return 1
	var games: Array = hub_script.GAMES
	if games.size() != 15:
		print("FAIL GAMES size %d" % games.size())
		failed += 1
	var titles: Dictionary = {}
	var found_new := false
	for game in games:
		var title := str(game.get("title", ""))
		var scene := str(game.get("scene", ""))
		if titles.has(title):
			print("FAIL duplicate title %s" % title)
			failed += 1
		titles[title] = true
		if not bool(game.get("built", false)):
			print("FAIL unexpected unbuilt %s" % title)
			failed += 1
		if scene.is_empty() or not ResourceLoader.exists(scene):
			print("FAIL missing scene %s -> %s" % [title, scene])
			failed += 1
		if title == "各点一次":
			found_new = true
			if scene != "res://scenes/SelfOrder.tscn":
				print("FAIL 各点一次 scene")
				failed += 1
			if str(game.get("func", "")) != "工作记忆 · 自我监控":
				print("FAIL 各点一次 func")
				failed += 1
	if not found_new:
		print("FAIL 各点一次 not registered")
		failed += 1
	return failed


func _check_self_order_logic() -> int:
	var failed := 0
	var script := load("res://scripts/SelfOrder.gd")
	if script == null:
		print("FAIL load SelfOrder.gd")
		return 1
	var cols := {
		4: 2,
		5: 3,
		6: 3,
		7: 3,
		8: 4,
		9: 3,
		10: 4,
		12: 4,
	}
	for n in cols:
		var got: int = script.grid_columns(n)
		if got != cols[n]:
			print("FAIL grid_columns(%d)=%d want %d" % [n, got, cols[n]])
			failed += 1
	for n in [4, 6, 8, 12]:
		var rects: Array = script.slot_rects(n, 600.0)
		if rects.size() != n:
			print("FAIL slot_rects size %d" % n)
			failed += 1
			continue
		# slots should not overlap and should stay in board
		for i in range(n):
			var a: Rect2 = rects[i]
			if a.position.x < -0.01 or a.position.y < -0.01 or a.end.x > 600.01 or a.end.y > 600.01:
				print("FAIL slot %d out of board at n=%d" % [i, n])
				failed += 1
			for j in range(i + 1, n):
				if a.intersects(rects[j]):
					print("FAIL slots overlap n=%d %d/%d" % [n, i, j])
					failed += 1
		var prev: Array[int] = []
		for i in range(n):
			prev.append(i)
		var moved_ok := 0
		for _k in range(20):
			var nxt: Array[int] = script.shuffled_slots(n, prev)
			if nxt.size() != n:
				print("FAIL shuffle size")
				failed += 1
				break
			var seen: Dictionary = {}
			var moved := 0
			for i in range(n):
				if nxt[i] < 0 or nxt[i] >= n or seen.has(nxt[i]):
					print("FAIL shuffle not a permutation")
					failed += 1
					break
				seen[nxt[i]] = true
				if nxt[i] != prev[i]:
					moved += 1
			if moved >= maxi(n / 2, 1):
				moved_ok += 1
			prev = nxt
		if moved_ok < 18:
			print("FAIL shuffle not moving enough (%d/20) n=%d" % [moved_ok, n])
			failed += 1
	var shapes: Dictionary = {}
	var colors: Dictionary = {}
	for tok in script.TOKENS:
		var s := int(tok["shape"])
		var c := str(tok["color"])
		if shapes.has(s):
			print("FAIL duplicate shape %d" % s)
			failed += 1
		shapes[s] = true
		if colors.has(c):
			print("FAIL duplicate token color %s" % c)
			failed += 1
		colors[c] = true
	if script.TOKENS.size() != 12 or shapes.size() != 12 or colors.size() != 12:
		print("FAIL token catalog size")
		failed += 1
	return failed


func _check_self_order_play() -> int:
	var packed := load("res://scenes/SelfOrder.tscn")
	if packed == null:
		print("FAIL load SelfOrder.tscn")
		return 1
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if int(game.set_size) != 4 or not bool(game.accepting):
		print("FAIL start state size=%s accepting=%s" % [game.set_size, game.accepting])
		game.queue_free()
		return 1
	# Tap each remaining token once (ids 0..3). After each correct mid-trial pick, wait for shuffle.
	for _i in range(4):
		var target := -1
		var picked: Array = game.picked
		for id in range(4):
			if not picked.has(id):
				target = id
				break
		if target < 0:
			print("FAIL no remaining token")
			game.queue_free()
			return 1
		if not bool(game.accepting):
			print("FAIL not accepting before tap %d" % target)
			game.queue_free()
			return 1
		game._on_tap(target)
		# last tap completes the set and goes to WAIT
		if _i < 3:
			await game.get_tree().create_timer(0.5).timeout
	await game.get_tree().create_timer(0.55).timeout
	if int(game.set_size) != 5:
		print("FAIL after complete set_size=%s score=%s" % [game.set_size, game.score])
		game.queue_free()
		return 1
	if int(game.score) <= 0 or int(game.streak) != 1:
		print("FAIL after complete score/streak %s %s" % [game.score, game.streak])
		game.queue_free()
		return 1
	# New trial should be accepting with 5 tokens; repeat the first pick to fail.
	if not bool(game.accepting) or int(game.phase) != game.Phase.PLAY:
		print("FAIL next trial not ready phase=%s accepting=%s" % [game.phase, game.accepting])
		game.queue_free()
		return 1
	game._on_tap(0)
	await game.get_tree().create_timer(0.5).timeout
	if not bool(game.accepting):
		print("FAIL not accepting after first pick of second trial")
		game.queue_free()
		return 1
	game._on_tap(0)
	if int(game.streak) != 0:
		print("FAIL repeat tap should break streak")
		game.queue_free()
		return 1
	await game.get_tree().create_timer(1.0).timeout
	if int(game.set_size) != 4:
		print("FAIL after miss set_size=%s" % game.set_size)
		game.queue_free()
		return 1
	game.queue_free()
	print("SELFORDER_PLAY_OK")
	return 0

