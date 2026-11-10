## The aircraft model, in plan (nose along +x, in metres): used for squadrons in battle, planes on a carrier's
## deck, and the machines on airfields and in air raids, so that every aircraft in the game is the same machine.
## `alt` is the height flown (it sets how far the shadow falls from the machine); `col` overrides the service paint.
static func draw(ci: CanvasItem, p: Vector2, a: float, sc: float, jet: bool, side: int, torp: bool, sun: Vector2, alt := -1.0, col = null, parked := false) -> void:
    var top: Color = Color(0.32, 0.36, 0.33) if side else Color(0.27, 0.36, 0.43)      # theirs olive grey, yours sea blue
    if jet: top = Color(0.5, 0.52, 0.5) if side else Color(0.56, 0.6, 0.62)
    if col != null: top = col
    var mark: Color = Color(0.78, 0.3, 0.24) if side else Color(0.93, 0.85, 0.55)
    var shapes: Array
    if jet:
        shapes = [PackedVector2Array([Vector2(6.4, 0), Vector2(4.6, -0.75), Vector2(-5.2, -0.8), Vector2(-6.0, -0.45), Vector2(-6.0, 0.45), Vector2(-5.2, 0.8), Vector2(4.6, 0.75)]),   # fuselage
            PackedVector2Array([Vector2(1.6, -0.7), Vector2(-3.4, -5.3), Vector2(-4.6, -5.3), Vector2(-2.2, -0.7)]), PackedVector2Array([Vector2(1.6, 0.7), Vector2(-2.2, 0.7), Vector2(-4.6, 5.3), Vector2(-3.4, 5.3)]),   # swept wings
            PackedVector2Array([Vector2(-4.2, -0.6), Vector2(-6.2, -2.4), Vector2(-6.8, -2.4), Vector2(-5.8, -0.6)]), PackedVector2Array([Vector2(-4.2, 0.6), Vector2(-5.8, 0.6), Vector2(-6.8, 2.4), Vector2(-6.2, 2.4)])]   # tailplane
    else:
        shapes = [PackedVector2Array([Vector2(4.6, 0), Vector2(4.2, -0.72), Vector2(1.5, -0.8), Vector2(-4.6, -0.3), Vector2(-5.2, 0), Vector2(-4.6, 0.3), Vector2(1.5, 0.8), Vector2(4.2, 0.72)]),   # fuselage
            PackedVector2Array([Vector2(2.2, -0.7), Vector2(1.5, -6.3), Vector2(0.2, -6.5), Vector2(-0.6, -6.1), Vector2(-0.9, -0.7)]), PackedVector2Array([Vector2(2.2, 0.7), Vector2(-0.9, 0.7), Vector2(-0.6, 6.1), Vector2(0.2, 6.5), Vector2(1.5, 6.3)]),   # wings
            PackedVector2Array([Vector2(-3.7, -0.3), Vector2(-4.1, -2.3), Vector2(-4.9, -2.3), Vector2(-5.0, -0.2)]), PackedVector2Array([Vector2(-3.7, 0.3), Vector2(-5.0, 0.2), Vector2(-4.9, 2.3), Vector2(-4.1, 2.3)])]   # tailplane
    if alt < 0.0: alt = 28.0 if torp else 60.0
    ci.draw_set_transform(p + sun * alt * 0.5, a, Vector2(sc, sc))
    for sh in shapes: ci.draw_colored_polygon(sh, Color(0.0, 0.03, 0.05, 0.28))
    ci.draw_set_transform(p, a, Vector2(sc, sc))
    var rs: Vector2 = sun.rotated(-a)                       # the sun's direction in the aircraft's own axes
    for i in shapes.size():
        var c: Color = top
        if i == 1 or i == 3: c = top.lightened(0.12) if rs.y > 0.0 else top.darkened(0.14)   # one wing takes the light, the other loses it
        if i == 2 or i == 4: c = top.lightened(0.12) if rs.y < 0.0 else top.darkened(0.14)
        ci.draw_colored_polygon(shapes[i], c)
    ci.draw_line(Vector2(3.6 if not jet else 5.0, 0), Vector2(-4.4, 0), top.lightened(0.14), 0.35)                    # the spine catching the light
    ci.draw_colored_polygon(PackedVector2Array([Vector2(2.2, -0.42), Vector2(0.2, -0.5), Vector2(-0.6, -0.3), Vector2(-0.6, 0.3), Vector2(0.2, 0.5), Vector2(2.2, 0.42)]) if not jet else PackedVector2Array([Vector2(4.0, -0.4), Vector2(2.0, -0.5), Vector2(1.2, 0), Vector2(2.0, 0.5), Vector2(4.0, 0.4)]), Color(0.1, 0.14, 0.17))   # canopy
    ci.draw_line(Vector2(1.6, -0.2), Vector2(0.4, -0.2), Color(0.75, 0.85, 0.9, 0.6), 0.14)                               # a glint on the glass
    var wy: float = 3.9 if jet else 4.6; var wx: float = -2.6 if jet else 0.5
    for sy in [-1.0, 1.0]: ci.draw_circle(Vector2(wx, sy * wy), 0.62, mark); ci.draw_circle(Vector2(wx, sy * wy), 0.26, top.darkened(0.3))   # wing markings
    if parked: ci.draw_circle(Vector2(4.2, 0), 0.7, top.darkened(0.25)) if not jet else ci.draw_circle(Vector2(-6.0, 0), 0.4, top.darkened(0.4))   # engines stopped
    elif jet:
        ci.draw_circle(Vector2(-6.3, 0), 0.5, Color(1, 0.7, 0.35, 0.9)); ci.draw_texture_rect(GameData.glow_tex(), Rect2(-10.5, -2.0, 5.0, 4.0), false, Color(1, 0.6, 0.3, 0.45))
    else:
        ci.draw_circle(Vector2(4.2, 0), 0.7, top.darkened(0.25)); ci.draw_arc(Vector2(4.75, 0), 1.75, 0, TAU, 16, Color(0.8, 0.82, 0.8, 0.16), 0.9)   # cowling and the propeller's disc
        if torp: ci.draw_line(Vector2(2.4, 0), Vector2(-2.6, 0), Color(0.62, 0.64, 0.62), 0.42)                         # the torpedo slung beneath
