extends CardScript
## Tranquility — {2}{G} — Sorcery (2ed, common)
## Oracle: Destroy all enchantments.
##
## Implementation: DestroyAllEffect filtered to enchantments — auras
## included (they are enchantments on the battlefield). The dos486 guide's
## sorcery-speed answer to the dreaded dungeon Power Struggle.


func build() -> CardData:
	return CardData.new("Tranquility", "{2}{G}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all enchantments", _is_enchantment)) \
		.oracle("Destroy all enchantments.")


static func _is_enchantment(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ENCHANTMENT)
