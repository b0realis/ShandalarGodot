extends CardScript
## Keldon Warlord — {2}{R}{R} — Creature — Human Barbarian — */* (2ed, uncommon)
## Oracle: Keldon Warlord's power and toughness are each equal to the
##         number of non-Wall creatures you control.
##
## Implementation: dynamic stats counting the CONTROLLER's non-Wall
## creatures — itself included, so it is never smaller than 1/1 while it
## lives. Go wide and the warlord grows.


func build() -> CardData:
	return CardData.new("Keldon Warlord", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["human", "barbarian"]) \
		.static_ability(StaticAbility.new(
			_apply, "Power and toughness equal to the number of non-Wall creatures you control.").setting_base_pt()) \
		.oracle("Keldon Warlord's power and toughness are each equal to the number of non-Wall creatures you control.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var troops := 0
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature() and not inst.has_subtype("wall"):
			troops += 1
	source.cur_power = troops
	source.cur_toughness = troops
