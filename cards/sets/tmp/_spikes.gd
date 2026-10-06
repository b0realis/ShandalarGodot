extends RefCounted
## Tempest (_spikes, Pack 9). Spikes: creatures that enter with +1/+1
## counters and move them to other creatures.
##
## Conventions (sth/_spikes.gd and exo/_spikes.gd preload the helpers at
## the bottom):
## - "This creature enters with N +1/+1 counters on it" is
##   CardData.with_enters_counters (a replacement as it enters, CR 614.1c);
##   the printed body is 0/0, so a Spike with no counter left dies to the
##   toughness state-based action (CR 704.5f).
## - "Remove a +1/+1 counter from this creature" is a COST
##   (ActivatedAbility.with_counter_cost, CR 602.2b): paid at activation,
##   so two activations can never spend one counter, and the Spike that
##   pays its last one dies with the ability on the stack, which still
##   resolves (CR 608.2b — only its target is re-checked).
## - Under the modern presets +1/+1 and -1/-1 counters annihilate
##   (CR 704.5q, `counters_annihilate`); under 1997 rules they coexist. The
##   engine does it; nothing here reads it.
## - AI: the move is a CounterMarkerEffect with the `stat_counter` role
##   (the shape homelands_tactics.gd reads); the shared scorer leaves a
##   +1/+1 counter cost alone ("the counter IS the body") until Stage 4.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Spike Drone":
			c.with_enters_counters("+1/+1", 1)
			c.activated(move_ability())
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## "{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on
## target creature." — every Spike's first ability. Any creature, either
## player's, the Spike itself included.
static func move_ability() -> ActivatedAbility:
	return ActivatedAbility.new("{2}", false,
		[CounterMarkerEffect.new("+1/+1", 1, TargetSpec.creature()).with_ai_role(&"stat_counter")],
		"{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on target creature.") \
		.with_counter_cost("+1/+1", 1)

## "[param cost], Remove a +1/+1 counter from this creature: <effect>."
static func counter_ability(cost: String, effect: EffectBase, text: String) -> ActivatedAbility:
	return ActivatedAbility.new(cost, false, [effect], text).with_counter_cost("+1/+1", 1)
