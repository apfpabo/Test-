extends Node
## Screenshots: the refit screen with a mount picked far down the list (gold ring on the plan, scroll kept), the ship
## systems, and the chart's orders box with its tooltip. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_refit.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var port: Dictionary
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    Campaign.new_game("commission"); Campaign.G.credits = 200000
    for p in Campaign.G.ports: if p.name == "Calder Roads": port = p
    for c in Diplomacy.offers(port): if Diplomacy.can_accept(c) == "": Diplomacy.accept(c)
    Campaign.accept_mission("concord")
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
    f += 1
    if f == 5: map.open_port(port); map.port_tab = "refit"; map.refit_sel = 0; map._render_port()
    if f == 10: map._panel_scroll.scroll_vertical = 120
    if f == 14: map.refit_sel = 6; map._render_port()   # "Details" on a mount far down the list
    if f == 22: _shot("refit_scrolled")
    if f == 24: map._panel_scroll.scroll_vertical = 2000
    if f == 30: _shot("refit_systems"); map.close_panel()
    if f == 38: _shot("orders_box")
    if f == 40:
        var b: Button = map.orders_list.get_child(1); var t := Label.new(); t.text = b.tooltip_text; t.position = Vector2(700, 300); t.size = Vector2(600, 300); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var bg := ColorRect.new(); bg.color = Color(0, 0, 0, 0.85); bg.position = t.position - Vector2(8, 8); bg.size = Vector2(616, 220); map.ui.add_child(bg); map.ui.add_child(t)
    if f == 44: _shot("orders_tooltip")
    if f == 46:   # warn and ask: a fit well over her margin (the heaviest gun each mount takes)
        map.open_port(port, false); map.port_tab = "refit"; map.refit_idx = 0; var s: Dictionary = Campaign.G.fleet[0]; var d: Dictionary = GameData.hulls[s.type]
        var plan: Array = s.fit.duplicate()
        for i in d.slots.size():
            var best := ""; var bt := -1.0
            for wid in GameData.weapons: if map._fits(wid, d.slots[i].s) and BattleSim.weapon_tons(wid) > bt: bt = BattleSim.weapon_tons(wid); best = wid
            var was = plan[i]; plan[i] = best
            if not BattleSim.loading(d, plan, s.get("up", {})).ok: plan[i] = was   # over her margin, but within what the yard passes
        map.refit_plan[s.id] = plan; var ld: Dictionary = BattleSim.loading(d, plan, s.get("up", {}))
        print("plan over %.0f t, ok %s, speed %.2f, spread %.2f" % [ld.over_t, ld.ok, ld.speed, ld.spread])
        map.refit_warn = String(s.id); map._render_port()
    if f == 50: map._panel_scroll.scroll_vertical = 1400
    if f == 54: _shot("refit_warn"); get_tree().quit()
