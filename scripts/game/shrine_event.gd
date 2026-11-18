extends "res://scripts/game/road_event.gd"
## Road event: Ember Shrine (once per run). Pay flame now for an extra reroll
## every wave for the rest of the run, or grab flame now and face tougher
## spirits tonight, or walk on.


func _ready() -> void:
	_build("Ember Shrine", Color("#ffb36b"), "A roadside shrine smoulders in the dusk. Old embers glow in its bowl.", [
		["Kneel and Offer", "Give −%d flame. For the rest of the run: +%d reroll every wave."
			% [roundi(Defs.SHRINE_OFFER_COST), Defs.SHRINE_REROLLS], _offer],
		["Take the Embers", "+%d flame now. The shrine's keepers follow: tonight's spirits have +%d%% HP."
			% [roundi(Defs.SHRINE_TAKE_HEAL), roundi((Defs.SHRINE_CURSE_HP - 1.0) * 100)], _take],
		["Walk On", "Leave the shrine be. Nothing gained, nothing lost.", _walk_on],
	])


func _offer() -> void:
	Run.flame = maxf(1.0, Run.flame - Defs.SHRINE_OFFER_COST)
	Run.bonus_rerolls += Defs.SHRINE_REROLLS
	AudioDirector.play_sfx("chime", -2.0)
	_result("The embers flare and settle into your dice. (+%d reroll every wave)" % Defs.SHRINE_REROLLS)


func _take() -> void:
	Run.flame = minf(Run.max_flame, Run.flame + Defs.SHRINE_TAKE_HEAL)
	Run.shrine_curse = true
	_result("Char swallows the embers (+%d flame). Behind you, the shrine goes dark... and something stirs." % roundi(Defs.SHRINE_TAKE_HEAL))


func _walk_on() -> void:
	_result("You bow your head and walk on. The shrine keeps its embers.")
