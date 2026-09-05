extends CardScript
## Whimsy — {X}{U}{U} — Sorcery — (past, common)
## Oracle: Play X random fast effects.
##
## `Duel.hlp`, MicroProse Clarifications: *"If an effect requires a target,
## the targeting is also random. If there are no valid targets for a chosen
## fast effect, that fast effect fizzles."*
##
## Implementation: X rolls on [RandomEffectTable] — the 1997 game's list of
## seventeen (`@WHIMSY_MESSAGES`: Time Elemental, Twiddle untap, Twiddle
## tap, Aladdin's Ring, Ancestral Recall, Crumble, Disenchant, Healing
## Salve, Fissure, Millstone, The Hive, Nevinyrral's Disk, Bottle of
## Suleiman, Pandora's Box, Disrupting Scepter, Fog, Sindbad) — one after
## another, each announced with its 1997 line, each resolving fully before
## the next is rolled (so a Fissure really can remove the creature the next
## roll wanted to Twiddle), each rolling its own target and fizzling, on
## the record, when it finds none. The Bottle's coin call and the Scepter's
## discard go through the DecisionAgent funnel. Everything rolls on
## [member MtgGame.rng], so a seeded duel replays a Whimsy exactly.
##
## Whimsy takes no targets of its own (the effects roll theirs when they
## are played, which is when they exist), so it never fizzles as a spell —
## a Whimsy for X=0 simply does nothing, as printed.


func build() -> CardData:
	return CardData.new("Whimsy", "{X}{U}{U}", Mtg.CardType.SORCERY) \
		.spell(WhimsyEffect.new()) \
		.oracle("Play X random fast effects.")


class WhimsyEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, x_value: int = 0) -> void:
		for _i in x_value:
			RandomEffectTable.play_random(game, source, controller)

	func describe() -> String:
		return "plays X random fast effects"
