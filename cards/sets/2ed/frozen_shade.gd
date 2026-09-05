extends CardScript
## Frozen Shade — {2}{B} — Creature — Shade — 0/1 (2ed, common)
## Oracle: {B}: This creature gets +1/+1 until end of turn.
##
## Implementation: the "shade" self-pump — an activated ability (mana cost,
## no tap, so it stacks up as many activations as black mana allows) whose
## payload is PumpEffect.self_buff(). Each activation adds a floating
## until-EOT effect; they all expire at cleanup together.


func build() -> CardData:
	return CardData.new("Frozen Shade", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["shade"]) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[PumpEffect.new(1, 1).self_buff()],
			"{B}: This creature gets +1/+1 until end of turn.")) \
		.oracle("{B}: This creature gets +1/+1 until end of turn.")
