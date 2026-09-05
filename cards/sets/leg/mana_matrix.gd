extends CardScript
## Mana Matrix — {6} — Artifact — (leg, rare)
## Oracle: Instant and enchantment spells you cast cost {2} less to cast.
##
## Implementation: a NEGATIVE cost modifier (the same hook Gloom uses to
## tax). MtgGame clamps a reduction at minus the printed GENERIC part, so
## a {U} instant still needs its blue mana — reductions never eat coloured
## pips (CR 601.2f).


func build() -> CardData:
	return CardData.new("Mana Matrix", "{6}", Mtg.CardType.ARTIFACT) \
		.with_cost_modifier(_discount) \
		.oracle("Instant and enchantment spells you cast cost {2} less to cast.")


## The modifier is asked about ITS OWN source, so "spells you cast" is the
## Matrix's controller — two opposing Matrices no longer discount each
## other's spells (and two of your own correctly stack).
static func _discount(_game: MtgGame, caster: int, data: CardData,
		source: CardInstance) -> int:
	if source.controller_id != caster:
		return 0
	if data.is_type(Mtg.CardType.INSTANT) or data.is_type(Mtg.CardType.ENCHANTMENT):
		return -2
	return 0
