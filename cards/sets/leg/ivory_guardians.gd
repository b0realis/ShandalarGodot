extends CardScript
## Ivory Guardians — {4}{W}{W} — Creature — Giant Cleric — 3/3 — (leg, uncommon)
## Oracle: Protection from red
##         Creatures named Ivory Guardians get +1/+1 as long as an opponent
##         controls a nontoken red permanent.
##
## Implementation: printed protection from red (the full DEBT bundle —
## red burn can't even target it) plus a conditional static that boosts
## every Ivory Guardians on the battlefield, including itself and a
## second copy. "Nontoken" is checked: this pool really does make red
## tokens (Rukh Egg's Bird, Boris Devilboon's Minor Demons, Hazezon's
## Sand Warriors, Stangg's Twin), and none of them switch the Guardians on.


func build() -> CardData:
	return CardData.new("Ivory Guardians", "{4}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["giant", "cleric"]) \
		.with_protection_from(Mtg.ManaColor.R) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures named Ivory Guardians get +1/+1 as long as an opponent "
			+ "controls a nontoken red permanent.")) \
		.oracle("Protection from red\nCreatures named Ivory Guardians get +1/+1 as long "
			+ "as an opponent controls a nontoken red permanent.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var found := false
	for inst in game.all_battlefield():
		if inst.is_token:
			continue   # "a NONTOKEN red permanent"
		if inst.controller_id != source.controller_id \
				and (inst.cur_colors & Mtg.ManaColor.R) != 0:
			found = true
			break
	if not found:
		return
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.data.card_name == "Ivory Guardians":
			inst.cur_power += 1
			inst.cur_toughness += 1
