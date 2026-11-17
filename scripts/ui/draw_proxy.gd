extends Control
## A Control that draws with a callable: draw_fn(canvas_item). Handy for
## one-off custom drawing on top of UI (drag ghosts, map lines).

var draw_fn: Callable


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
