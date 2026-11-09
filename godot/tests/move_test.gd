extends Node
## Chart movement check: a fleet under way is given a new course 90° off its heading, then a long route. Reports how
## far its track ever slips sideways from where the bow points (it should not slide), the lowest speed in the turn,
## and whether it arrives. godot --headless --path godot res://tests/move_test.tscn
func _ready() -> void:
    Campaign.new_game("commission")
    var P: Dictionary = Campaign.G.player
    for fl in Campaign.G.fleets: fl.cool = 9999.0
    P.cool = 9999.0
    # open water in the Hesperian Ocean, heading east at speed
    P.x = Campaign.lon_x(25.0); P.y = Campaign.lat_y(40.0); P.h = 0.0; P.v = Campaign.fleet_map_speed(Campaign.G.fleet)
    Campaign.set_course(P, P.x + 400.0, P.y)
    for i in 60: Campaign.update(1.0 / 30.0)
    var v0: float = P.v
    Campaign.set_course(P, P.x, P.y + 300.0)   # hard turn south
    var worst_slip := 0.0; var vmin := INF; var prev := Vector2(P.x, P.y); var arrived := false; var t := 0
    for i in 30 * 120:
        Campaign.update(1.0 / 30.0); t = i
        var p := Vector2(P.x, P.y); var mv := Vector2(Campaign.wdx(prev.x, p.x), p.y - prev.y)
        if mv.length() > 0.05: worst_slip = maxf(worst_slip, absf(Campaign.ang_diff(mv.angle(), P.h)))
        if i < 30 * 4: vmin = minf(vmin, P.v)   # during the turn, not the final approach
        prev = p
        if P.get("route") == null: arrived = true; break
    print("speed before turn %.1f, lowest in the turn %.1f (%.0f%%), worst slip %.1f deg, arrived %s after %.1f s" % [v0, vmin, vmin / v0 * 100.0, rad_to_deg(worst_slip), arrived, t / 30.0])
    # a long route through a strait: Calder Roads to Kotaraya, the whole way without grounding
    var a: Dictionary = Campaign.G.ports[0]; P.x = a.sx; P.y = a.sy; P.v = 0.0
    var b: Dictionary = {}
    for q in Campaign.G.ports: if q.name == "Kotaraya": b = q
    Campaign.G.cargo.fuel = 99999.0   # a long passage: don't let the bunkers run dry
    Campaign.set_course(P, b.sx, b.sy); var aground := 0; arrived = false
    for i in 30 * 600:
        Campaign.update(1.0 / 30.0)
        if Campaign.on_land(P.x, P.y): aground += 1
        if P.get("route") == null: arrived = true; t = i; break
    print("Calder Roads -> Kotaraya: arrived %s after %.0f s, %d steps on land, %.0f units from the port" % [arrived, t / 30.0, aground, Campaign.mdist(P.x, P.y, b.sx, b.sy)])
    get_tree().quit()
