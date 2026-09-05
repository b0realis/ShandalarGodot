extends CardScript
## Purelace — {W} — Instant — (2ed, rare)
## Oracle: Target spell or permanent becomes white. (Mana symbols on that permanent remain unchanged.)
##
## Implementation: the colour change is INDEFINITE (CR 613 layer 5) — it
## rides on CardInstance.color_override, so it survives the cleanup step,
## and a Laced SPELL keeps the colour when it resolves into a permanent.
## The parenthetical is automatic here: mana costs are never rewritten,
## only Mtg.ManaColor masks.


func build() -> CardData:
	return CardData.new("Purelace", "{W}", Mtg.CardType.INSTANT) \
		.spell(ChangeColorEffect.new(Mtg.ManaColor.W)) \
		.oracle("Target spell or permanent becomes white. (Mana symbols on that permanent remain unchanged.)")
