extends CardScript
## Kobold Overlord — {1}{R} — Creature — Kobold — 1/2 — (leg, rare)
## Oracle: First strike
##         Other Kobold creatures you control have first strike.
##
## Implementation: printed first strike plus a keyword-granting lord.
## With the Taskmaster's +1/+0 the free Kobolds become 1/1 first
## strikers — the whole point of the Kher Keep deck.


func build() -> CardData:
	return CardData.new("Kobold Overlord", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["kobold"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.static_ability(StaticAbility.new(
			_apply, "Other Kobold creatures you control have first strike.")) \
		.oracle("First strike\nOther Kobold creatures you control have first strike.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.controller_id == source.controller_id \
				and inst.is_creature() and inst.has_subtype("kobold") \
				and not inst.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
			inst.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)
