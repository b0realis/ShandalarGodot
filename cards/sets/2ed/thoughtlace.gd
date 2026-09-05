extends CardScript
## Thoughtlace — {U} — Instant — (2ed, rare)
## Oracle: Target spell or permanent becomes blue. (Mana symbols on that permanent remain unchanged.)
##
## Implementation: the colour change is INDEFINITE (CR 613 layer 5) — it
## rides on CardInstance.color_override, so it survives the cleanup step,
## and a Laced SPELL keeps the colour when it resolves into a permanent.
## The parenthetical is automatic here: mana costs are never rewritten,
## only Mtg.ManaColor masks.


func build() -> CardData:
	return CardData.new("Thoughtlace", "{U}", Mtg.CardType.INSTANT) \
		.spell(ChangeColorEffect.new(Mtg.ManaColor.U)) \
		.oracle("Target spell or permanent becomes blue. (Mana symbols on that permanent remain unchanged.)")
