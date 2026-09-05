extends CardScript
## Argivian Blacksmith — {1}{W}{W} — Creature — Human Artificer — 2/2 —
## (atq, common)
## Oracle: {T}: Prevent the next 2 damage that would be dealt to target
##         artifact creature this turn.
##
## Implementation: PreventDamageEffect with a filtered creature spec — the
## target must be an artifact creature (LIVE types, so an animated Mishra's
## Factory qualifies). Antiquities' repair crew for the Juggernaut decks.


func build() -> CardData:
	return CardData.new("Argivian Blacksmith", "{1}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "artificer"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[PreventDamageEffect.new(2).target_creature(
				"target artifact creature", _is_artifact_creature)],
			"{T}: Prevent the next 2 damage to target artifact creature this turn.")) \
		.oracle("{T}: Prevent the next 2 damage that would be dealt to target artifact creature this turn.")


static func _is_artifact_creature(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
