extends Control
## The world as a globe: the chart's far overview (owner's choice, 11 Nov 2026: the flat chart stays for play; scrolling
## out past its widest view, or the Globe button, shows the world whole). Ports in their powers' colours, your squadron,
## who is at war with you. Drag to turn it; scroll in, click a place, or Esc to go back to the chart there.
## The sphere is ray-cast in shaders/globe.gdshader from the chart's own terrain; the marks are drawn here, projected
## the same way (orthographic: `project`).
var map                     # the chart (world_map.gd)
var lon0 := 0.0             # the longitude and latitude facing the viewer, radians
var lat0 := 0.3
var k := 1.0                # the globe's size, as a multiple of its resting size
var shown := 0.0            # 0..1, fading in and out
var closing := false
var spin := Vector2.ZERO    # the turn it was left with when the drag was let go (radians a second)
var dragging := false
var moved := 0.0
var hover = null            # the port under the pointer
var sphere: ColorRect
var marks: Control
var mat: ShaderMaterial
const K_MIN := 0.7
const K_MAX := 2.6

class Marks extends Control:
    var globe
    func _draw() -> void: globe.draw_marks(self)

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP; visible = false
    sphere = ColorRect.new(); sphere.set_anchors_preset(Control.PRESET_FULL_RECT); sphere.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(sphere)
    mat = ShaderMaterial.new(); mat.shader = load("res://shaders/globe.gdshader"); sphere.material = mat
    if ResourceLoader.exists("res://data/terrain.png"): mat.set_shader_parameter("terrain", load("res://data/terrain.png"))
    mat.set_shader_parameter("lat_top", float(Campaign.LAT0)); mat.set_shader_parameter("lat_span", float(Campaign.MH) / float(Campaign.DEG))
    marks = Marks.new(); marks.globe = self; marks.set_anchors_preset(Control.PRESET_FULL_RECT); marks.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(marks)

## A control set straight on a canvas layer does not take the window's size from its anchors: it is given here.
func _fit() -> void:
    var vs: Vector2 = get_viewport_rect().size
    if size != vs: position = Vector2.ZERO; size = vs
    for c in [sphere, marks]: if c.size != vs: c.position = Vector2.ZERO; c.size = vs

func radius() -> float: return minf(size.x, size.y) * 0.36 * k * (1.0 + 0.5 * (1.0 - _ease(shown)))
func centre() -> Vector2: return Vector2(size.x * 0.5, size.y * 0.5 + 14.0)
func _ease(x: float) -> float: return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
func lon_of(x: float) -> float: return deg_to_rad(x / float(Campaign.DEG) - 180.0)
func lat_of(y: float) -> float: return deg_to_rad(float(Campaign.LAT0) - y / float(Campaign.DEG))

## Where a place on the chart (map units) falls on the screen, and whether it is on the side facing you (z > 0).
func project(x: float, y: float) -> Vector3:
    var lon: float = lon_of(x) - lon0; var lat: float = lat_of(y)
    var px: float = cos(lat) * sin(lon)
    var py: float = cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(lon)
    var pz: float = sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(lon)
    var c := centre(); var r := radius()
    return Vector3(c.x + px * r, c.y - py * r, pz)

## The place on the chart under a point of the screen (map units), or null off the globe.
func unproject(sp: Vector2):
    var p: Vector2 = (sp - centre()) / radius(); p.y = -p.y
    if p.length_squared() >= 1.0: return null
    var z: float = sqrt(1.0 - p.length_squared())
    var lat: float = asin(clampf(z * sin(lat0) + p.y * cos(lat0), -1.0, 1.0))
    var lon: float = lon0 + atan2(p.x, z * cos(lat0) - p.y * sin(lat0))
    return Vector2(Campaign.wrap_x((rad_to_deg(lon) + 180.0) * float(Campaign.DEG)), clampf((float(Campaign.LAT0) - rad_to_deg(lat)) * float(Campaign.DEG), 0.0, float(Campaign.MH)))

func open() -> void:
    if visible and not closing: return
    lon0 = lon_of(map.cam.x); lat0 = clampf(lat_of(map.cam.y), -1.2, 1.2); k = 1.0; spin = Vector2.ZERO; closing = false; dragging = false; hover = null
    visible = true; _fit()
func close(at = null) -> void:
    if not visible or closing: return
    closing = true
    var to: Vector2 = at if at != null else Vector2(Campaign.wrap_x((rad_to_deg(lon0) + 180.0) * float(Campaign.DEG)), (float(Campaign.LAT0) - rad_to_deg(lat0)) * float(Campaign.DEG))
    # (wide, but not so wide that the whole height of the chart is in view: then the chart centres itself, not on the place chosen)
    map.free_cam = true; map.cam = to; map.zoom = maxf(map.zoom, get_viewport_rect().size.y / float(Campaign.MH) * 1.35)
func is_open() -> bool: return visible and not closing

func _process(d: float) -> void:
    if not visible: return
    _fit()
    shown = move_toward(shown, 0.0 if closing else 1.0, d / 0.32)
    if closing and shown <= 0.0: visible = false; closing = false; map.overlay.visible = true; map.dock.modulate.a = 1.0; map.world.visible = true; return
    if not closing and map.panel_open: close()   # something on the chart wants you: a contact, a port
    if not dragging and spin.length() > 0.002:   # it runs on a little when let go, and comes to rest
        lon0 += spin.x * d; lat0 = clampf(lat0 + spin.y * d, -1.35, 1.35); spin *= pow(0.04, d)
    lon0 = wrapf(lon0, -PI, PI)
    mat.set_shader_parameter("size", size); mat.set_shader_parameter("mid", centre()); mat.set_shader_parameter("radius", radius())
    mat.set_shader_parameter("centre", Vector2(lon0, lat0)); mat.set_shader_parameter("fade", _ease(shown))
    marks.modulate.a = _ease(shown); marks.queue_redraw()
    # the chart's own names, scales and dock button belong to the flat chart: away while the world is shown
    map.overlay.visible = shown < 0.5; map.dock.modulate.a = 1.0 - _ease(shown); map.world.visible = shown < 0.999

func _gui_input(e: InputEvent) -> void:
    if closing: return
    if e is InputEventMouseButton:
        var mb := e as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
            if k >= K_MAX - 0.01: close(unproject(mb.position))   # in past the nearest view: down to the chart, at the place under the pointer
            else: k = minf(K_MAX, k * 1.12)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: k = maxf(K_MIN, k / 1.12)
        elif mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed: dragging = true; moved = 0.0; spin = Vector2.ZERO
            else:
                dragging = false
                if moved < 5.0:   # a click, not a drag: go to the chart there (or at the port clicked)
                    if hover != null: close(Vector2(hover.x, hover.y))
                    else:
                        var w = unproject(mb.position)
                        if w != null: close(w)
        elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed: close()
        accept_event()
    elif e is InputEventMouseMotion:
        var mm := e as InputEventMouseMotion
        if dragging:
            moved += mm.relative.length()
            var r := radius(); var dl := Vector2(-mm.relative.x / r / maxf(cos(lat0), 0.3), mm.relative.y / r)
            lon0 += dl.x; lat0 = clampf(lat0 + dl.y, -1.35, 1.35)
            spin = spin.lerp(dl / maxf(get_process_delta_time(), 0.004), 0.35)
        hover = _port_at(mm.position)
        accept_event()

func _input(e: InputEvent) -> void:
    if not is_open(): return
    if e is InputEventKey and e.pressed and not e.is_echo():
        match (e as InputEventKey).keycode:
            KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
            KEY_EQUAL, KEY_KP_ADD:
                if k >= K_MAX - 0.01: close()
                else: k = minf(K_MAX, k * 1.25)
                get_viewport().set_input_as_handled()
            KEY_MINUS, KEY_KP_SUBTRACT: k = maxf(K_MIN, k / 1.25); get_viewport().set_input_as_handled()

func _port_at(sp: Vector2):
    var best = null; var bd := 13.0
    for p in Campaign.G.ports:
        var q := project(p.x, p.y)
        if q.z <= 0.05: continue
        var dd: float = Vector2(q.x, q.y).distance_to(sp)
        if dd < bd: bd = dd; best = p
    return best

func _col(fac: String) -> Color:
    return Color(String(GameData.fac[fac].get("map", "#c8c8c0"))) if GameData.fac.has(fac) else Color(0.6, 0.62, 0.6)
## How a power stands with you, in a word and a colour.
func _stand(fac: String) -> Array:
    if fac == "player": return ["yours", UI.GOLD]
    if Campaign.at_war(fac): return ["at war with you", UI.RED]
    if Campaign.hostile(fac): return ["hostile", Color(0.93, 0.62, 0.4)]
    var rep: float = float(Campaign.G.rep.get(fac, 0))
    return ["friendly", UI.GREEN] if rep >= 25.0 else ["neutral", UI.DIM]

func draw_marks(ci: Control) -> void:
    var G: Dictionary = Campaign.G; var f13: Font = UI.font("regular"); var fc: Font = UI.font("cond"); var r := radius(); var c := centre()
    # the sea lanes you are bound along: the course in hand, laid over the curve of the world
    var route = G.player.get("route")
    if route != null and route is Array and not route.is_empty():
        var prev := project(G.player.x, G.player.y)
        for i in range(int(G.player.get("ri", 0)), route.size()):
            var wp: Vector2 = route[i]; var q := project(wp.x, wp.y)
            if q.z > 0.0 and prev.z > 0.0: ci.draw_line(Vector2(prev.x, prev.y), Vector2(q.x, q.y), Color(UI.GOLD, 0.55), 1.5, true)
            prev = q
    # ports: a dot in its power's colour, a ring round a capital, a red ring if that power is at war with you
    var named: Array = []
    for p in G.ports:
        var q := project(p.x, p.y)
        if q.z <= 0.04: continue
        var at := Vector2(q.x, q.y); var col := _col(p.fac); var cap: bool = p.get("capital", false); var a: float = clampf(q.z * 3.0, 0.0, 1.0)
        var rad: float = (4.2 if cap else 2.8) * clampf(sqrt(k), 0.85, 1.5)
        ci.draw_circle(at, rad + 1.4, Color(0.02, 0.05, 0.06, 0.85 * a)); ci.draw_circle(at, rad, Color(col, a))
        if cap: ci.draw_arc(at, rad + 3.2, 0, TAU, 20, Color(col, 0.8 * a), 1.2, true)
        if p.fac != "player" and Campaign.at_war(p.fac): ci.draw_arc(at, rad + (6.0 if cap else 3.4), 0, TAU, 20, Color(UI.RED, 0.85 * a), 1.2, true)
        if p == hover: ci.draw_arc(at, rad + 8.0, 0, TAU, 24, Color(UI.INK, 0.9), 1.5, true)
        if (cap or k >= 1.7 or p.fac == "player") and q.z > 0.25 and p != hover: named.append([at, p, a])
    for nm in named:   # names after every dot, so no dot sits on a name
        var p: Dictionary = nm[1]; var at: Vector2 = nm[0]
        ci.draw_string(fc, at + Vector2(8, 4), String(p.name).to_upper() if p.get("capital", false) else String(p.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if p.get("capital", false) else 11, Color(0.88, 0.92, 0.9, 0.75 * float(nm[2])))
    # you
    var me := project(G.player.x, G.player.y)
    if me.z > 0.0:
        var at := Vector2(me.x, me.y); var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
        ci.draw_arc(at, 9.0 + 5.0 * pulse, 0, TAU, 28, Color(UI.GOLD, 0.55 * (1.0 - pulse)), 1.5, true)
        ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)]), UI.GOLD)
        ci.draw_string(fc, at + Vector2(10, -8), "YOUR SQUADRON", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.GOLD)
    else:   # on the far side: an arrow at the limb, the shortest way round
        var lon: float = lon_of(G.player.x) - lon0; var lat: float = lat_of(G.player.y)
        var dir := Vector2(cos(lat) * sin(lon), -(cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(lon))).normalized()
        var at := c + dir * (r + 16.0)
        ci.draw_colored_polygon(PackedVector2Array([at + dir * 8.0, at + dir.orthogonal() * 5.0, at - dir.orthogonal() * 5.0]), UI.GOLD)
        ci.draw_string(fc, at + dir * 14.0 + Vector2(-50, 4), "YOUR SQUADRON", HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color(UI.GOLD, 0.9))
    if hover != null:
        var q := project(hover.x, hover.y); var at := Vector2(q.x, q.y) + Vector2(14, -10)
        var st: Array = _stand(hover.fac); var who: String = String(GameData.fac[hover.fac].name) if GameData.fac.has(hover.fac) else String(hover.fac)
        var l1: String = String(hover.name) + (" · capital" if hover.get("capital", false) else ""); var l2: String = who + " · " + String(st[0])
        var w: float = maxf(f13.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, f13.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 20.0
        at.x = minf(at.x, size.x - w - 8.0)
        ci.draw_rect(Rect2(at + Vector2(0, -18), Vector2(w, 44)), Color(0.03, 0.08, 0.1, 0.92)); ci.draw_rect(Rect2(at + Vector2(0, -18), Vector2(w, 44)), Color(UI.GOLD, 0.5), false, 1.0)
        ci.draw_string(f13, at + Vector2(10, 0), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.INK)
        ci.draw_string(f13, at + Vector2(10, 17), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, st[1])
    # the powers, and how each stands with you
    var y: float = size.y - 150.0; var x := 22.0; var rows: Array = []
    for fac in GameData.fac:
        if fac == "raiders": continue
        var n := 0
        for p in G.ports: if p.fac == fac: n += 1
        if n > 0 or fac == "player": rows.append([fac, n])
    y = size.y - 96.0 - rows.size() * 18.0
    ci.draw_string(fc, Vector2(x, y - 8.0), "THE POWERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
    for row in rows:
        var fac: String = row[0]; var st: Array = _stand(fac)
        y += 18.0
        ci.draw_circle(Vector2(x + 5, y - 4), 4.5, _col(fac))
        ci.draw_string(f13, Vector2(x + 18, y), String(GameData.fac[fac].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK)
        ci.draw_string(f13, Vector2(x + 240, y), "%d port%s · %s" % [row[1], "" if row[1] == 1 else "s", st[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, st[1])
    ci.draw_string(fc, Vector2(22, 74), "THE WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.INK)
    ci.draw_string(f13, Vector2(22, 94), "Drag to turn · scroll in, or click a place, to go down to the chart there · Esc: back", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
