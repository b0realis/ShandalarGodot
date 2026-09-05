extends CardScript
## Kird Ape — {R} — Creature — Ape — 1/1 (arn, common)
## Oracle: Kird Ape gets +1/+2 as long as you control a Forest.
##
## Implementation: a CONDITIONAL SELF static — checks the controller's
## lands (by subtype, so Taiga counts, which is precisely the classic
## Kird Ape mana base) on every recalculation. The first Arabian Nights
## rules card to graduate.


func build() -> CardData:
	return CardData.new("Kird Ape", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["ape"]) \
		.static_ability(StaticAbility.new(
			_apply, "Kird Ape gets +1/+2 as long as you control a Forest.")) \
		.oracle("Kird Ape gets +1/+2 as long as you control a Forest.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_land() and inst.has_subtype("forest"):
			source.cur_power += 1
			source.cur_toughness += 2
			return
