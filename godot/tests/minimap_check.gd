extends Node
## A click on the battle minimap moves the camera there and keeps the zoom (13 Nov 2026).
var battle: Node
var f := 0
var fails := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1
func _ready() -> void:
	GameData.pending = {"player": ["dd_fletcher"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	f += 1
	if f == 5:
		var z: Vector2 = battle.camera.zoom; var r: Rect2 = battle.hud.minimap_rect()
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = r.position + r.size * Vector2(0.25, 0.75)
		battle._unhandled_input(e)
		var want: Vector2 = Vector2(battle.sim.AW * 0.25, battle.sim.AH * 0.75)
		ok(battle.camera.position.distance_to(want) < 50.0 and battle.camera.zoom == z and battle.cam_free, "camera at %s (want %s), zoom kept" % [battle.camera.position, want])
		var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = e.position; battle._unhandled_input(up)
		print("DONE fails=%d" % fails); get_tree().quit(1 if fails else 0)
