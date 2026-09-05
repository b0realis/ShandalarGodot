extends CardScript
## Avoid Fate — {G} — Instant — (leg, common)
## Oracle: Counter target instant or Aura spell that targets a permanent
##         you control.
##
## Implementation: CounterEffect with two filters — a plain one for the
## card type (instant or Aura) and a SOURCE-aware one that walks the stack
## for the target spell's own targets and demands at least one of them be
## a permanent Avoid Fate's controller controls. Green's answer to Terror
## and to a hostile aura, for one mana.


func build() -> CardData:
	var counter := CounterEffect.new(
		"target instant or Aura spell that targets a permanent you control",
		_is_instant_or_aura)
	counter.target_spec.with_source_filter(_targets_your_permanent)
	return CardData.new("Avoid Fate", "{G}", Mtg.CardType.INSTANT) \
		.spell(counter) \
		.oracle("Counter target instant or Aura spell that targets a permanent you control.")


static func _is_instant_or_aura(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.INSTANT) or inst.data.is_aura()


static func _targets_your_permanent(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	for item in game.stack:
		if item.kind != Mtg.StackKind.SPELL or item.card != inst:
			continue
		for ref in item.targets:
			if ref.is_player:
				continue
			var aimed := game.find_instance(ref.instance_id)
			if aimed != null and aimed.zone == Mtg.Zone.BATTLEFIELD \
					and aimed.controller_id == source.controller_id:
				return true
	return false
