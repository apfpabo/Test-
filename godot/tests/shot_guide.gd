extends Node
## The new captain's guide (scripts/guide.gd): each chart step moves on when it is done, the aftermath card ends it,
## and a first action carries its battle steps. Pictures of the cards.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_guide.tscn -- <dir>
const Guide = preload("res://scripts/guide.gd")
var map: Node
var battle: Node
var f := 0
var out := ""
var bad := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: bad += 1
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/guide_%s.png" % [out, n])
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("merchant"); Guide.start()
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _step() -> int: return int(Campaign.G.guide.get("step", -1)) if Campaign.G.has("guide") else -1
func _process(_d: float) -> void:
	f += 1
	if f == 5: ok(map.guide_card != null and _step() == 0, "a new captain gets the guide on the chart"); _shot("1_look")
	if f == 8: map.zoom *= 1.5
	if f == 80: ok(_step() == 1, "zooming the chart moves it on (step %d)" % _step()); _shot("2_fleet")
	if f == 82: map.cmd_tab = "fleet"; map.show_command()
	if f == 150:
		ok(_step() == 2, "opening the fleet page moves it on (step %d)" % _step()); map.close_drawer()
		var P: Dictionary = Campaign.G.player; var best = null
		for p in Campaign.G.ports: if not Campaign.hostile(p.fac) and (best == null or Campaign.mdist(p.sx, p.sy, P.x, P.y) < Campaign.mdist(best.sx, best.sy, P.x, P.y)) and Campaign.mdist(p.sx, p.sy, P.x, P.y) > 30.0: best = p
		Campaign.set_course(P, best.sx, best.sy); P.destPort = int(best.id)
	if f == 220: ok(_step() == 3, "setting a course moves it on (step %d)" % _step()); map._speed(4); _shot("3_clock")
	if f == 290: ok(_step() == 4, "running the clock moves it on (step %d)" % _step()); map.open_port(Campaign.G.ports[0])
	if f == 360: ok(_step() == 5, "making harbour moves it on (step %d)" % _step()); _shot("4_port"); map.close_panel(); map.cur_port = {}
	if f == 370: Campaign.G.guide.step = Guide.CHART.size(); map.guide_card._show()   # (at sea, past the last chart card)
	if f == 375:
		var a := [Campaign.new_ship("ca_baltimore", "Quincy Bay", "player", [])]; var b := [Campaign.new_ship("dd_narvik", null, "directorate", [])]
		GameData.pending = {"player_recs": a, "enemy_recs": b, "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
		battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle); map.visible = false
	if f == 385: _shot("5_battle"); ok(int(Campaign.G.guide.battle) == 0, "the first action opens with the battle guide")
	if f == 386: battle.sim.flag.throttle = 4
	if f == 460: ok(int(Campaign.G.guide.battle) == 1, "using the engines moves it on")
	if f == 462: battle.sim.lock = battle.sim.ships[1]
	if f == 530: ok(int(Campaign.G.guide.battle) == 2, "laying the guns on an enemy moves it on"); _shot("6_guns"); battle.queue_free(); map.visible = true
	if f == 540: map._show_aftermath({"victory": true, "retreated": false, "sunk": [], "lost": [], "prizes": [], "coin": 0, "rp": 0, "goods": "", "bounty": 0, "casualties": 0, "notes": [], "wrecks": []})
	if f == 548: _shot("7_after"); ok(map.guide_card.card.visible and bool(Campaign.G.guide.after), "the aftermath gives the last card")
	if f == 550: map.guide_card._advance()
	if f == 556:
		ok(not Campaign.G.has("guide"), "and Next there ends the guide")
		print("GUIDE TEST PASSED" if bad == 0 else "GUIDE TEST FAILED (%d)" % bad); get_tree().quit(0 if bad == 0 else 1)
