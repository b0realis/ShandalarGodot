extends CardScript
## Pyrotechnics — {4}{R} — Sorcery — (4ed, uncommon)
## Oracle: Pyrotechnics deals 4 damage divided as you choose among any
##         number of targets.
##
## Implementation: the first card of the divided-damage family. The caster
## supplies one TargetRef per recipient, each carrying its share in
## TargetRef.amount; TargetPlan checks the shares add up to 4 and that
## every chosen target gets at least 1 (CR 601.2d). A single chosen target
## absorbs all 4 automatically, so `[TargetRef.card(bear)]` still works.


func build() -> CardData:
	return CardData.new("Pyrotechnics", "{4}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).any_target().divided(4)) \
		.oracle("Pyrotechnics deals 4 damage divided as you choose among any number of targets.")
