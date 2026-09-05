extends CardScript
## Akron Legionnaire — {6}{W}{W} — Creature — Giant Soldier — 8/4 — (leg, rare)
## Oracle: Except for creatures named Akron Legionnaire and artifact
##         creatures, creatures you control can't attack.
##
## Implementation: an 8/4 that costs you your whole ground assault — a
## static setting cur_cant_attack on the controller's other, non-artifact
## creatures. Reads LIVE types, so an animated Mishra's Factory (an
## artifact creature) is exempt and still swings. Blocking is untouched.


func build() -> CardData:
	return CardData.new("Akron Legionnaire", "{6}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(8, 4) \
		.with_subtypes(["giant", "soldier"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Except for creatures named Akron Legionnaire and artifact creatures, "
			+ "creatures you control can't attack.")) \
		.oracle("Except for creatures named Akron Legionnaire and artifact creatures, "
			+ "creatures you control can't attack.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.controller_id != source.controller_id or not inst.is_creature():
			continue
		if inst.data.card_name == "Akron Legionnaire":
			continue
		if inst.is_type(Mtg.CardType.ARTIFACT):
			continue
		inst.cur_cant_attack = true
