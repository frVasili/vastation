class_name InfoBlock
extends Control
## Focused tile title (72 px) + subtitle (28 px); changes cross-slide (old out left, new in from right, 0.18 s).

var margin_left := 212.0
var _cur: Control
var _tween: Tween

func show_tile(tile: Dictionary, animate: bool) -> void:
	var next := _make(tile)
	add_child(next)
	if _cur != null:
		var old := _cur
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(old, "position:x", -70.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(old, "modulate:a", 0.0, 0.18)
			tw.chain().tween_callback(old.queue_free)
			next.position.x = 90.0
			next.modulate.a = 0.0
			var tw2 := create_tween().set_parallel(true)
			tw2.tween_property(next, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw2.tween_property(next, "modulate:a", 1.0, 0.18)
			Perf.kick(0.5)
		else:
			old.queue_free()
	_cur = next

func _make(tile: Dictionary) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avail := size.x - margin_left - 48.0
	var title := LabelLine.make(str(tile.get("title", "")), 72, 800, Pal.text, 2)
	title.box_w = avail
	title.position = Vector2(margin_left, 0)
	box.add_child(title)
	var sub := LabelLine.make(str(tile.get("subtitle", "")), 28, 500, Color(Pal.text, 0.75))
	sub.box_w = avail
	sub.position = Vector2(margin_left + 2, title.size.y + 2)
	box.add_child(sub)
	return box
