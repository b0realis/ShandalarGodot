extends CardScript
## Giant Tortoise — {1}{U} — Creature — Turtle — 1/1 — (4ed, common)
## Oracle: This creature gets +0/+3 as long as it's untapped.
##
## Implementation: a self-referential static reading the LIVE tap state on
## every recalculation — a 1/4 wall on defense that shrinks to a 1/1 the
## moment it attacks (attacking taps it). The engine recalculates on tap,
## so the shrink is visible immediately.


func build() -> CardData:
	return CardData.new("Giant Tortoise", "{1}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["turtle"]) \
		.static_ability(StaticAbility.new(
			_apply, "Giant Tortoise gets +0/+3 as long as it's untapped.")) \
		.oracle("This creature gets +0/+3 as long as it's untapped.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	if not source.tapped:
		source.cur_toughness += 3
