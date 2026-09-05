extends CardScript
## Drudge Skeletons — {1}{B} — Creature — Skeleton — 1/1 (2ed, common)
## Oracle: {B}: Regenerate this creature. (The next time it would be
##         destroyed this turn, it isn't. Instead tap it, remove all damage
##         from it, and remove it from combat.)
##
## Implementation: the reference REGENERATION card — an activated ability
## (mana cost only, no tap) whose payload is RegenerateEffect, building a
## shield that MtgGame.destroy consumes. Terror ("can't be regenerated")
## and Wrath of God ignore the shield; the tests pin both directions.


func build() -> CardData:
	return CardData.new("Drudge Skeletons", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["skeleton"]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[RegenerateEffect.new()],
			"{B}: Regenerate this creature.")) \
		.oracle("{B}: Regenerate this creature.")
