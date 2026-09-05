extends CardScript
## Flood — {U} — Enchantment — (4ed, common)
## Oracle: {U}{U}: Tap target creature without flying.
##
## Implementation: an enchantment with a repeatable activated TapEffect
## restricted to grounded creatures (live keyword check) — blue's slow
## ground-lock.


func build() -> CardData:
	var grounded := TargetSpec.creature("target creature without flying", _grounded)
	return CardData.new("Flood", "{U}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{U}{U}", false,
			[TapEffect.new(grounded)],
			"{U}{U}: Tap target creature without flying.")) \
		.oracle("{U}{U}: Tap target creature without flying.")


static func _grounded(inst: CardInstance) -> bool:
	return not inst.has_keyword(Mtg.Keyword.FLYING)
