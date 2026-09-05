extends CardScript
## Time Vault — {2} — Artifact — (2ed, rare)
## Oracle: This artifact enters tapped.
##         This artifact doesn't untap during your untap step.
##         If you would begin your turn while this artifact is tapped, you
##         may skip that turn instead. If you do, untap this artifact.
##         {T}: Take an extra turn after this one.
##
## Implementation: all four lines. Entering tapped and the untap ban are
## the two flags every such permanent uses; the {T} queues an extra turn
## through the path Time Walk uses.
##
## The skip-your-turn clause is a CR 614.10 replacement of the turn's
## BEGINNING (CardData.skips_turn_to_untap): as the controller's turn
## would begin, before its untap step, MtgGame._begin_turn puts
## `@TIME_VAULT`'s question — "Play this turn." / "Skip this turn to
## untap." — through the turn-based hold, so a human seat is held on it
## like an untap-step question. A skipped turn is proceeded past as though
## it did not exist (CR 500.9): no untap step, no upkeep, no draw, no
## cleanup, and the Vault untaps. Two tapped Vaults untap one per skipped
## turn — a turn once skipped is no longer beginning (CR 616.1), which is
## Duel.hlp's own ruling ("You cannot untap multiple Time Vaults by
## skipping the same turn"). The heuristic skips one turn in five, as the
## 1997 AI did (`card_time_vault`, 0x420280 — decompiled). Lifted
## 2026-09-02.
##
## 1997 vs Oracle: Duel.hlp prints the 1994 wording — skipping put a "turn
## counter" on the Vault and the extra turn cost removing them — while the
## engine follows Oracle, where the tapped/untapped state alone carries
## the same information. The ruling that goes with it is the same either
## way: "As your turn begins (and before your untap phase begins), you
## decide whether or not to skip that turn."


func build() -> CardData:
	return CardData.new("Time Vault", "{2}", Mtg.CardType.ARTIFACT) \
		.with_enters_tapped() \
		.static_ability(StaticAbility.new(_never_untaps,
			"This artifact doesn't untap during your untap step.")) \
		.with_skip_turn_to_untap() \
		.activated(ActivatedAbility.new("", true, [ExtraTurnEffect.new()],
			"{T}: Take an extra turn after this one.")) \
		.oracle("This artifact enters tapped.\nThis artifact doesn't untap during your untap step.\nIf you would begin your turn while this artifact is tapped, you may skip that turn instead. If you do, untap this artifact.\n{T}: Take an extra turn after this one.")


static func _never_untaps(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true
