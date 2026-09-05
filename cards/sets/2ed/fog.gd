extends CardScript
## Fog — {G} — Instant (2ed, common)
## Oracle: Prevent all combat damage that would be dealt this turn.
##
## Implementation: PreventCombatDamageEffect — it raises
## MtgGame.combat_damage_prevented; the combat-damage step checks the flag
## and skips both waves; cleanup clears it. Cast it during the
## declare-blockers priority round and the whole attack fizzles into mist.
## Non-combat damage (Bolt, Pestilence) is untouched, as printed.


func build() -> CardData:
	return CardData.new("Fog", "{G}", Mtg.CardType.INSTANT) \
		.spell(PreventCombatDamageEffect.new()) \
		.oracle("Prevent all combat damage that would be dealt this turn.")
