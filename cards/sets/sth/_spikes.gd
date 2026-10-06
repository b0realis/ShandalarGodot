extends RefCounted
## Stronghold (_spikes, Pack 9). Spikes: creatures that enter with +1/+1
## counters and move them to other creatures.
##
## The shared shape is cards/sets/tmp/_spikes.gd (P): the entering
## counters, the "{2}, Remove a +1/+1 counter from this creature: Put a
## +1/+1 counter on target creature" move, and every other "Remove a +1/+1
## counter from this creature" ability as a counter COST paid at
## activation (CR 602.2b).
##
## - Spike Breeder's token is a 1/1 green Spike, a creature like any other
##   (it can take a moved counter).
## - Spike Soldier's +2/+2 lasts until end of turn and is applied to the
##   Spike that activated it, only while it is still that object (CR 400.7).
const P := preload("res://cards/sets/tmp/_spikes.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Spike Breeder":
			c.with_enters_counters("+1/+1", 3)
			c.activated(P.move_ability())
			c.activated(P.counter_ability("{2}", CreateTokenEffect.new("Spike", 1, 1, Mtg.ManaColor.G, "spike"),
				"{2}, Remove a +1/+1 counter from this creature: Create a 1/1 green Spike creature token."))
		"Spike Colony":
			c.with_enters_counters("+1/+1", 4)
			c.activated(P.move_ability())
		"Spike Feeder":
			c.with_enters_counters("+1/+1", 2)
			c.activated(P.move_ability())
			c.activated(P.counter_ability("", GainLifeEffect.new(2),
				"Remove a +1/+1 counter from this creature: You gain 2 life."))
		"Spike Soldier":
			c.with_enters_counters("+1/+1", 3)
			c.activated(P.move_ability())
			c.activated(P.counter_ability("", PumpEffect.new(2, 2).self_buff(),
				"Remove a +1/+1 counter from this creature: This creature gets +2/+2 until end of turn."))
		"Spike Worker":
			c.with_enters_counters("+1/+1", 2)
			c.activated(P.move_ability())
		_: return false
	return true
