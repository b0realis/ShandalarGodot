extends CardScript
## Plague Rats — {2}{B} — Creature — Rat — */* (2ed, common)
## Oracle: Plague Rats' power and toughness are each equal to the number
##         of creatures named Plague Rats on the battlefield.
##
## Implementation: the Nightmare dynamic-stats pattern, counting BY NAME
## across BOTH battlefields (rats swarm together whoever controls them —
## as printed). Each new rat pumps the whole pack; the classic all-rats
## deck emerges naturally.


func build() -> CardData:
	return CardData.new("Plague Rats", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["rat"]) \
		.static_ability(StaticAbility.new(
			_apply, "Power and toughness equal to the number of creatures named Plague Rats on the battlefield.").setting_base_pt()) \
		.oracle("Plague Rats' power and toughness are each equal to the number of creatures named Plague Rats on the battlefield.")


## A FACE-DOWN permanent has no name (CR 708.2) — an Illusionary Mask'd
## Plague Rats is no rat until it is turned up; it counted as one until the
## bug hunt of 2026-10-21.
static func _apply(game: MtgGame, source: CardInstance) -> void:
	var rats := 0
	for inst in game.all_battlefield():
		if inst.data.card_name == "Plague Rats" and not inst.face_down:
			rats += 1
	source.cur_power = rats
	source.cur_toughness = rats
