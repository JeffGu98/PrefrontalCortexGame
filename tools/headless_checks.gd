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
	failed += await _check_hub_scroll_vs_tap()
	failed += await _check_p0_fixes()
	failed += await _check_p1_features()
	if failed == 0:
		print("HEADLESS_CHECKS_OK")
		quit(0)
	else:
		print("HEADLESS_CHECKS_FAILED %d" % failed)
		quit(1)


func _check_versions() -> int:
	var failed := 0
	var project := str(ProjectSettings.get_setting("application/config/version", ""))
	if project != "1.8.2":
		print("FAIL version project=%s" % project)
		failed += 1
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets.find('version/name="1.8.2"') < 0 or presets.find("version/code=182") < 0:
		print("FAIL export_presets version")
		failed += 1
	if presets.find('export_path="build/PrefrontalCortexGame-1.8.2.apk"') < 0:
		print("FAIL export_path")
		failed += 1
	if presets.find('include_filter="assets/schulte/*"') >= 0:
		print("FAIL stale assets/schulte include_filter still in export_presets.cfg")
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
	if games.size() != 11:
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
	var kept := ["反向色字", "舒尔特方格", "追踪异色球", "N-Back", "积木跨度", "各点一次", "末项记", "看点数", "任务切换", "规则变了", "汉诺塔"]
	for title in kept:
		if not titles.has(title):
			print("FAIL missing kept game %s" % title)
			failed += 1
	for title in ["反向反应", "中间箭头", "线索靶", "红灯停"]:
		if titles.has(title):
			print("FAIL removed game still registered %s" % title)
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


func _check_hub_scroll_vs_tap() -> int:
	var packed := load("res://scenes/Hub.tscn")
	if packed == null:
		print("FAIL load Hub.tscn")
		return 1
	var hub: Node = packed.instantiate()
	root.add_child(hub)
	for _i in range(6):
		await process_frame
	var opened: Array = []
	hub.open_intercept = func(path: String) -> void:
		opened.append(path)
	var scroll: ScrollContainer = hub._scroll
	if scroll == null:
		print("FAIL hub has no scroll")
		hub.queue_free()
		return 1
	var bar := scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= bar.page + 8.0:
		print("FAIL hub list is not tall enough to scroll max=%s page=%s" % [bar.max_value if bar else -1, bar.page if bar else -1])
		hub.queue_free()
		return 1
	var card: Control = _find_enabled_hub_card(scroll)
	if card == null:
		print("FAIL no hub card")
		hub.queue_free()
		return 1
	var failed := 0
	var ver_label := hub.get_node_or_null("VersionLabel") as Label
	var expected_ver := "v%s" % str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if ver_label == null or ver_label.text != expected_ver:
		print("FAIL hub VersionLabel got=%s want=%s" % [ver_label.text if ver_label else "<missing>", expected_ver])
		failed += 1
	# v1.7.0 system back: first press arms, does not quit the tree.
	if bool(hub._quit_armed):
		print("FAIL quit already armed")
		failed += 1
	hub._on_system_back()
	if not bool(hub._quit_armed):
		print("FAIL system back did not arm quit")
		failed += 1
	hub._disarm_quit()
	if bool(hub._quit_armed):
		print("FAIL disarm quit failed")
		failed += 1

	# Headless --script has no OS window, so Viewport.push_input never
	# reaches GUI. Drive the card's _gui_input with the same event shapes.
	var pos := card.global_position + card.size * 0.5
	var start_y := int(scroll.scroll_vertical)
	# Small move stays a tap (threshold is 14).
	_card_gesture(card, pos, Vector2(0, 4))
	if opened.size() != 1:
		print("FAIL short move should tap, opened=%s" % [opened])
		failed += 1
	if abs(int(scroll.scroll_vertical) - start_y) > 2:
		print("FAIL short move scrolled to %s from %s" % [scroll.scroll_vertical, start_y])
		failed += 1
	opened.clear()

	# Finger moves up: list should scroll down, and must not open a game.
	start_y = int(scroll.scroll_vertical)
	pos = card.global_position + card.size * 0.5
	_card_gesture(card, pos, Vector2(0, -120))
	if opened.size() != 0:
		print("FAIL drag opened a game %s" % [opened])
		failed += 1
	var after_drag := int(scroll.scroll_vertical)
	if after_drag - start_y < 80:
		print("FAIL drag did not scroll enough start=%d now=%d" % [start_y, after_drag])
		failed += 1

	# Wheel over a card also scrolls.
	start_y = int(scroll.scroll_vertical)
	_card_wheel(card, card.global_position + card.size * 0.5, true)
	var after_wheel := int(scroll.scroll_vertical)
	if after_wheel <= start_y:
		print("FAIL wheel did not scroll start=%d now=%d" % [start_y, after_wheel])
		failed += 1

	hub.queue_free()
	await process_frame
	if failed == 0:
		print("HUB_SCROLL_VS_TAP_OK")
	return failed


func _find_enabled_hub_card(node: Node) -> Control:
	if node is Control and (node as Control).has_meta("hub_title"):
		var card := node as Control
		if card.get("is_disabled") != true:
			return card
	for child in node.get_children():
		var found := _find_enabled_hub_card(child)
		if found != null:
			return found
	return null


func _card_gesture(card: Control, start: Vector2, delta: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start - card.global_position
	down.global_position = start
	card._gui_input(down)
	var steps := 6
	var pos := start
	var step := delta / float(steps)
	for _i in range(steps):
		pos += step
		var motion := InputEventMouseMotion.new()
		motion.position = pos - card.global_position
		motion.global_position = pos
		motion.relative = step
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		card._gui_input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = start + delta - card.global_position
	up.global_position = start + delta
	card._gui_input(up)


func _card_wheel(card: Control, pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = pos - card.global_position
	ev.global_position = pos
	ev.factor = 1.0
	card._gui_input(ev)


func _check_p0_fixes() -> int:
	var failed := 0
	# 1. RuleShift choice piles must shuffle and preserve exact 1-dimension match.
	var rs_script := load("res://scripts/RuleShift.gd")
	if rs_script == null:
		print("FAIL load RuleShift.gd")
		return 1
	var seen_piles: Dictionary = {}
	var stim := {"color": 1, "shape": 2, "count": 0}
	for _k in range(30):
		var built: Dictionary = rs_script.build_trial_choices(stim, rs_script.DIM_COLOR)
		var choices: Array = built["choices"]
		var cp := int(built["correct_pile"])
		if choices.size() != 3 or cp < 0 or cp > 2:
			print("FAIL RuleShift invalid trial")
			failed += 1
			break
		seen_piles[cp] = true
		if int(choices[cp]["color"]) != int(stim["color"]):
			print("FAIL RuleShift correct_pile mismatch")
			failed += 1
			break
		for c in choices:
			var matches := 0
			if int(c["color"]) == int(stim["color"]):
				matches += 1
			if int(c["shape"]) == int(stim["shape"]):
				matches += 1
			if int(c["count"]) == int(stim["count"]):
				matches += 1
			if matches != 1:
				print("FAIL RuleShift choice match count=%d" % matches)
				failed += 1
				break
	if seen_piles.size() < 2:
		print("FAIL RuleShift piles did not shuffle")
		failed += 1

	# 2. Daily completion: opening daily card must not mark completed; real completion must.
	var hub_script := load("res://scripts/Hub.gd")
	if hub_script == null:
		print("FAIL load Hub.gd for P0 check")
		return failed + 1
	var daily_scene: String = hub_script.daily_scene_path()
	if daily_scene.is_empty():
		print("FAIL daily_scene_path empty")
		failed += 1
	var daily_cfg_backup := ""
	if FileAccess.file_exists(hub_script.DAILY_PATH):
		daily_cfg_backup = FileAccess.get_file_as_string(hub_script.DAILY_PATH)
	if FileAccess.file_exists(hub_script.DAILY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(hub_script.DAILY_PATH))
	var hub_packed := load("res://scenes/Hub.tscn")
	var hub: Node = hub_packed.instantiate()
	root.add_child(hub)
	await process_frame
	hub.open_intercept = func(_p: String) -> void:
		pass
	hub._open_daily(daily_scene)
	if hub_script.is_daily_completed_today():
		print("FAIL _open_daily marked daily completed prematurely")
		failed += 1
	if not hub_script.mark_daily_completed(daily_scene):
		print("FAIL mark_daily_completed returned false for today scene")
		failed += 1
	if not hub_script.is_daily_completed_today():
		print("FAIL is_daily_completed_today false after real completion")
		failed += 1
	hub.queue_free()
	await process_frame
	if daily_cfg_backup.is_empty():
		if FileAccess.file_exists(hub_script.DAILY_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(hub_script.DAILY_PATH))
	else:
		var f := FileAccess.open(hub_script.DAILY_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(daily_cfg_backup)
			f.close()

	# 3. Stroop responsive layout & split easy/hard best scores.
	var stroop_packed := load("res://scenes/Stroop.tscn")
	var stroop: Node = stroop_packed.instantiate()
	root.add_child(stroop)
	await process_frame
	if stroop.stim_panel.size.y > 260.0 or stroop.stim_panel.position.y + stroop.stim_panel.size.y >= stroop.choice_grid.position.y:
		print("FAIL Stroop stim_panel overlaps choice_grid")
		failed += 1
	stroop.easy_mode = true
	stroop._set_current_best(120)
	stroop.easy_mode = false
	stroop._set_current_best(45)
	if stroop.best_score_easy != 120 or stroop.best_score_hard != 45:
		print("FAIL Stroop split best scores")
		failed += 1
	stroop.queue_free()
	await process_frame

	# 4. Fresh start must not erase saved highest progress in Schulte / Track / Hanoi.
	for spec in [
		{"scene": "res://scenes/Schulte.tscn", "field": "latest_size", "val": 7, "gate_phase": 0, "cfg": "user://schulte_best.cfg"},
		{"scene": "res://scenes/Track.tscn", "field": "latest_balls", "val": 10, "gate_phase": 0, "cfg": "user://track_best.cfg"},
		{"scene": "res://scenes/Hanoi.tscn", "field": "latest_disks", "val": 5, "gate_phase": 0, "cfg": "user://hanoi_best.cfg"},
	]:
		var cfg_path: String = spec["cfg"]
		var cfg_backup := ""
		var had_cfg := FileAccess.file_exists(cfg_path)
		if had_cfg:
			cfg_backup = FileAccess.get_file_as_string(cfg_path)
		var p := load(spec["scene"])
		var g: Node = p.instantiate()
		root.add_child(g)
		await process_frame
		g.set(spec["field"], spec["val"])
		g.set("phase", spec["gate_phase"])
		g._on_progress_fresh()
		if int(g.get(spec["field"])) != int(spec["val"]):
			print("FAIL fresh start overwrote %s in %s" % [spec["field"], spec["scene"]])
			failed += 1
		g.queue_free()
		await process_frame
		if had_cfg:
			var fw := FileAccess.open(cfg_path, FileAccess.WRITE)
			if fw != null:
				fw.store_string(cfg_backup)
				fw.close()
		elif FileAccess.file_exists(cfg_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))

	if failed == 0:
		print("P0_FIXES_OK")
	return failed


func _backup_cfg(path: String) -> Dictionary:
	var had := FileAccess.file_exists(path)
	var content := FileAccess.get_file_as_string(path) if had else ""
	return {"path": path, "had": had, "content": content}


func _restore_cfg(snap: Dictionary) -> void:
	var path: String = snap["path"]
	if bool(snap["had"]):
		var fw := FileAccess.open(path, FileAccess.WRITE)
		if fw != null:
			fw.store_string(str(snap["content"]))
			fw.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_p1_features() -> int:
	var failed := 0

	# 1. Global mute setting roundtrip.
	var base_script := load("res://scripts/GameBase.gd")
	if base_script == null:
		print("FAIL load GameBase.gd")
		return 1
	var settings_snap := _backup_cfg(base_script.SETTINGS_PATH)
	base_script.set_muted(true)
	if not base_script.is_muted():
		print("FAIL GameBase.set_muted(true) did not persist")
		failed += 1
	base_script.set_muted(false)
	if base_script.is_muted():
		print("FAIL GameBase.set_muted(false) did not persist")
		failed += 1
	_restore_cfg(settings_snap)

	# 2. Track move duration curve: 6 balls -> 4.0s, 12+ balls -> 7.0s.
	var track_script := load("res://scripts/Track.gd")
	if track_script == null:
		print("FAIL load Track.gd")
		return failed + 1
	var d6: float = track_script.move_duration_for(6)
	var d12: float = track_script.move_duration_for(12)
	var d14: float = track_script.move_duration_for(14)
	if absf(d6 - 4.0) > 0.01 or absf(d12 - 7.0) > 0.01 or absf(d14 - 7.0) > 0.01:
		print("FAIL Track move_duration_for d6=%.2f d12=%.2f d14=%.2f" % [d6, d12, d14])
		failed += 1

	# 3. Hub per-game summary stat formatting.
	var hub_script := load("res://scripts/Hub.gd")
	var stroop_snap := _backup_cfg("user://stroop_best.cfg")
	var schulte_snap := _backup_cfg("user://schulte_best.cfg")
	var daily_snap := _backup_cfg(hub_script.DAILY_PATH)
	var c1 := ConfigFile.new()
	c1.set_value("best", "easy_score", 95)
	c1.set_value("best", "hard_score", 60)
	c1.save("user://stroop_best.cfg")
	var st_stroop: String = hub_script.game_stat_text("反向色字")
	if st_stroop.find("95") < 0 or st_stroop.find("60") < 0:
		print("FAIL Hub.game_stat_text(反向色字)=%s" % st_stroop)
		failed += 1
	var c2 := ConfigFile.new()
	c2.set_value("best", "size", 6)
	c2.set_value("best", "time_6", 18.4)
	c2.save("user://schulte_best.cfg")
	var st_schulte: String = hub_script.game_stat_text("舒尔特方格")
	if st_schulte.find("6×6") < 0 or st_schulte.find("18.4") < 0:
		print("FAIL Hub.game_stat_text(舒尔特方格)=%s" % st_schulte)
		failed += 1

	# 4. Stroop end summary card & switch-difficulty button flow.
	var stroop_packed := load("res://scenes/Stroop.tscn")
	var stroop: Node = stroop_packed.instantiate()
	root.add_child(stroop)
	await process_frame
	stroop._on_progress_continue()
	stroop.score = 80
	stroop.correct_count = 4
	stroop.total_trials = 5
	stroop.rt_sum = 3.2
	stroop.rt_count = 4
	stroop._end_game()
	if not bool(stroop._summary_panel.visible) or not bool(stroop._summary_secondary_btn.visible):
		print("FAIL Stroop summary card or switch-difficulty button not visible")
		failed += 1
	stroop._on_summary_secondary()
	if int(stroop.phase) != stroop.Phase.GATE or bool(stroop._summary_panel.visible):
		print("FAIL Stroop switch-difficulty did not return to GATE")
		failed += 1
	stroop.queue_free()
	await process_frame
	_restore_cfg(stroop_snap)
	_restore_cfg(schulte_snap)
	_restore_cfg(daily_snap)

	# 5. Deprecated Schulte animal silhouette assets and generator tool removed.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/schulte")):
		print("FAIL deprecated res://assets/schulte still exists")
		failed += 1
	if FileAccess.file_exists("res://tools/make_silhouette.gd"):
		print("FAIL deprecated res://tools/make_silhouette.gd still exists")
		failed += 1

	if failed == 0:
		print("P1_FEATURES_OK")
	return failed
