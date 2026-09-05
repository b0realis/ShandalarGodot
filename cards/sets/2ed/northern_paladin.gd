extends CardScript
## Northern Paladin — {2}{W}{W} — Creature — Human Knight — 3/3 — (2ed, rare)
## Oracle: {W}{W}, {T}: Destroy target black permanent.
##
## Implementation: mana + tap activated destruction, filtered to BLACK
## permanents of any type (creature, enchantment, Mox Jet...). Color is
## read from the mana cost (CR 105.2) — the only color source in this
## pool. mage-go: DestroyTargetPermanent + HasColorFilter(Black).


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target black permanent",
		_is_black)
	return CardData.new("Northern Paladin", "{2}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["human", "knight"]) \
		.activated(ActivatedAbility.new(
			"{W}{W}", true,
			[DestroyEffect.new(spec)],
			"{W}{W}, {T}: Destroy target black permanent.")) \
		.oracle("{W}{W}, {T}: Destroy target black permanent.")


static func _is_black(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.B) != 0
