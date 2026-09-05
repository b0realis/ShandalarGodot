extends CardScript
## Orc General — {2}{R} — Creature — Orc Warrior — 2/2 — (drk, uncommon)
## Oracle: {T}, Sacrifice another Orc or Goblin: Other Orc creatures get
##         +1/+1 until end of turn.
##
## Implementation: tap plus a filtered sacrifice cost (any other Orc or
## Goblin), paying for a MassPumpEffect narrowed to Orc creatures.
## The printed text says neither "you control" nor "you don't control", so
## EVERY Orc on the battlefield gets the boost — and "other" means other
## than this permanent (.excluding_source()), so a second Orc General you
## control is pumped while this one never pumps himself.


func build() -> CardData:
	return CardData.new("Orc General", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["orc", "warrior"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[MassPumpEffect.new(1, 1, "other Orc creatures").excluding_source() \
				.with_filter(_is_orc)],
			"{T}, Sacrifice another Orc or Goblin: Other Orc creatures get +1/+1 "
			+ "until end of turn.") \
			.with_sacrifice_of("other Orc or Goblin", _orc_or_goblin)) \
		.oracle("{T}, Sacrifice another Orc or Goblin: Other Orc creatures get +1/+1 "
			+ "until end of turn.")


static func _orc_or_goblin(inst: CardInstance) -> bool:
	return inst.is_creature() and (inst.has_subtype("orc") or inst.has_subtype("goblin"))


static func _is_orc(inst: CardInstance) -> bool:
	return inst.has_subtype("orc")
