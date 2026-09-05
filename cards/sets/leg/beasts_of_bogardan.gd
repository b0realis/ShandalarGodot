extends CardScript
## Beasts of Bogardan — {4}{R} — Creature — Beast — 3/3 — (leg, uncommon)
## Oracle: Protection from red
##         This creature gets +1/+1 as long as an opponent controls a
##         nontoken white permanent.
##
## Implementation: Ivory Guardians' mirror — a red creature with
## protection FROM red (so it walks past red removal and blocks red
## attackers for free), swelling against a white opponent. The static
## boosts only itself. "Nontoken" is checked: Hazezon Tamar's Sand
## Warriors are red, green AND white tokens, and they do not count.


func build() -> CardData:
	return CardData.new("Beasts of Bogardan", "{4}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["beast"]) \
		.with_protection_from(Mtg.ManaColor.R) \
		.static_ability(StaticAbility.new(
			_apply,
			"Beasts of Bogardan gets +1/+1 as long as an opponent controls a "
			+ "nontoken white permanent.")) \
		.oracle("Protection from red\nThis creature gets +1/+1 as long as an opponent "
			+ "controls a nontoken white permanent.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_token:
			continue   # "a NONTOKEN white permanent"
		if inst.controller_id != source.controller_id \
				and (inst.cur_colors & Mtg.ManaColor.W) != 0:
			source.cur_power += 1
			source.cur_toughness += 1
			return
