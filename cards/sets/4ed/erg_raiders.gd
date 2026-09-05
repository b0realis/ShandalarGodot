extends CardScript
## Erg Raiders — {1}{B} — Creature — Human Warrior — 2/3 (4ed, common;
## first printed in Arabian Nights)
## Oracle: At the beginning of your end step, if this creature didn't
##         attack this turn, it deals 2 damage to you unless it came under
##         your control this turn.
##
## Implementation: an END_STEP_START trigger whose condition reads the
## engine's per-turn combat bookkeeping (CardInstance.attacked_this_turn,
## set in declare_attackers, cleared at untap). "Came under your control
## this turn" is checked via summoning_sick — an exact proxy today because
## control never changes mid-turn in this engine; revisit if control-change
## effects land (noted in docs/ROADMAP.md). A dos486-guide staple: the best
## aggressive two-drop of the pool, kept honest by this drawback.


func build() -> CardData:
	return CardData.new("Erg Raiders", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["human", "warrior"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START,
			_punish,
			"At the beginning of your end step, if this creature didn't attack this turn, it deals 2 damage to you unless it came under your control this turn.",
			_should_punish)) \
		.oracle("At the beginning of your end step, if this creature didn't attack this turn, it deals 2 damage to you unless it came under your control this turn.")


static func _should_punish(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("player") == source.controller_id \
		and not source.attacked_this_turn \
		and not source.summoning_sick


static func _punish(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(source.controller_id), 2)
