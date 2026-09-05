extends CardScript
## Sage of Lat-Nam — {1}{U} — Creature — Human Artificer — 1/2 — (atq, common)
## Oracle: {T}, Sacrifice an artifact: Draw a card.
##
## Implementation: a tap-plus-sacrifice DrawEffect. Once per turn it turns
## a spent artifact (a cracked Mox, a used-up Rocket Launcher) into a
## card — the blue half of Antiquities' artifact economy.


func build() -> CardData:
	return CardData.new("Sage of Lat-Nam", "{1}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["human", "artificer"]) \
		.activated(ActivatedAbility.new(
			"", true, [DrawEffect.new(1)],
			"{T}, Sacrifice an artifact: Draw a card.") \
			.with_sacrifice_of("artifact", _is_artifact)) \
		.oracle("{T}, Sacrifice an artifact: Draw a card.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
