extends CardScript
## Ring of Immortals — {5} — Artifact — (leg, rare)
## Oracle: {3}, {T}: Counter target instant or Aura spell that targets a
##         permanent you control.
##
## Implementation: a narrow, reusable counterspell. Everything the printed
## text restricts is TARGETING (CR 115.4), so it all lives in the
## TargetSpec — the kind is SPELL, the instance filter checks "instant or
## Aura", and a source-aware filter walks the candidate spell's own chosen
## targets on the stack to see whether any of them is a permanent the
## Ring's controller controls. Aiming it at anything else is refused at
## activation rather than fizzling later.
##
## "Targets a permanent you control" reads the SPELL's target list off its
## stack item, which is where the engine keeps a cast spell's choices —
## so an Aura counts through the permanent it was cast to enchant.


func build() -> CardData:
	var counter := CounterEffect.new(
		"target instant or Aura spell that targets a permanent you control",
		_instant_or_aura)
	counter.target_spec.with_source_filter(_aims_at_our_stuff)
	return CardData.new("Ring of Immortals", "{5}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true, [counter],
			"{3}, {T}: Counter target instant or Aura spell that targets a permanent you control.")) \
		.oracle("{3}, {T}: Counter target instant or Aura spell that targets a permanent you control.")


static func _instant_or_aura(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.INSTANT) or inst.data.is_aura()


static func _aims_at_our_stuff(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	var item := game.find_stack_item(inst)
	if item == null:
		return false
	for ref in item.targets:
		if ref == null or ref.is_player:
			continue
		var aimed := game.find_instance(ref.instance_id)
		if aimed != null and aimed.zone == Mtg.Zone.BATTLEFIELD \
				and aimed.controller_id == source.controller_id:
			return true
	return false
