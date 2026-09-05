extends CardScript
## Cleanse — {2}{W}{W} — Sorcery — (leg, rare)
## Oracle: Destroy all black creatures.
##
## Implementation: DestroyAllEffect filtered on black. Colour reads the
## PRINTED mana cost (data.color_mask) — the project convention, since no
## colour-changing effect exists in this pool (docs/audit-vs-mage-go.md).
## Untargeted, so protection from white doesn't save a black creature.


func build() -> CardData:
	return CardData.new("Cleanse", "{2}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all black creatures", _is_black_creature)) \
		.oracle("Destroy all black creatures.")


static func _is_black_creature(inst: CardInstance) -> bool:
	return inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.B) != 0
