extends CardScript
## Shatterstorm — {2}{R}{R} — Sorcery — (atq, rare)
## Oracle: Destroy all artifacts. They can't be regenerated.
##
## Implementation: DestroyAllEffect over every artifact — artifact
## creatures included, since the filter reads the LIVE type mask — with
## can_regenerate = false. Symmetric, so the Shatterstorm deck plays few
## artifacts of its own. The era's answer to an artifact-heavy field.


func build() -> CardData:
	return CardData.new("Shatterstorm", "{2}{R}{R}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all artifacts", _is_artifact, false)) \
		.oracle("Destroy all artifacts. They can't be regenerated.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
