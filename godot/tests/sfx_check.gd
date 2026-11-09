extends Node
## Checks the recorded sound effects load: res://tests/sfx_check.tscn (headless).
func _ready() -> void:
    var ks = Sfx._rec.keys(); ks.sort()
    print("recorded banks: ", ks.size(), " ", ks, " · sea loop ", Sfx._engine.stream is AudioStreamOggVorbis and Sfx._engine.stream.loop, " · engine room ", Sfx._room.stream != null, " · sea bed ", Sfx._bed.stream != null, " · gulls ", Sfx._gulls.size())
    for k in ["gun_H", "hit", "splash", "ciws", "launch", "depth", "torp_hit"]: Sfx.event(k, 0.5)
    Sfx.auto_fire("ciws", 0.5); Sfx.engine(0.6)
    print("ok"); get_tree().quit()
