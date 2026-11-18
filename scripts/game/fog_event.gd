extends "res://scripts/game/road_event.gd"
## Road event: Fog Cloud. Press On risks a pothole; Make Camp Early heals but
## may draw a Mist Wisp ambush.


func _ready() -> void:
	_build("Fog Cloud", Color("#bcd2ff"), "A thick fog rolls over the road. Something drifts inside it.", [
		["Press On", "Drive through blind. The stagecoach may hit a pothole (%d%%: −%d flame)."
			% [roundi(Defs.POTHOLE_CHANCE * 100), roundi(Defs.POTHOLE_DAMAGE)], _press_on],
		["Make Camp Early", "Rest until it clears (+%d flame). Mist Wisps may find you first (%d%%)."
			% [roundi(Defs.CAMP_HEAL), roundi(Defs.AMBUSH_CHANCE * 100)], _make_camp],
	])


func _press_on() -> void:
	if Run.rng.randf() < Defs.POTHOLE_CHANCE:
		Run.flame = maxf(1.0, Run.flame - Defs.POTHOLE_DAMAGE)
		AudioDirector.play_sfx("hurt", -2.0)
		_result("Thunk! The stagecoach hits a pothole (−%d flame)." % roundi(Defs.POTHOLE_DAMAGE))
	else:
		_result("The wheels find the road. You come through the fog unharmed.")


func _make_camp() -> void:
	if Run.rng.randf() < Defs.AMBUSH_CHANCE:
		_result("Mist Wisps drift out of the fog toward your camp!", true, "Defend the Camp", "One wave, Mist Wisps only.")
	else:
		Run.flame = minf(Run.max_flame, Run.flame + Defs.CAMP_HEAL)
		_result("A quiet rest. The fog lifts by nightfall (+%d flame)." % roundi(Defs.CAMP_HEAL))
