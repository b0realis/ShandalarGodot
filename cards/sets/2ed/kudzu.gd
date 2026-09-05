extends CardScript
## Kudzu — {1}{G}{G} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant land
##         When enchanted land becomes tapped, destroy it. That land's
##         controller may attach this Aura to a land of their choice.
##
## Implementation: green's creeping land destruction. The trigger watches
## BECAME_TAPPED on the host (Psychic Venom's hook — tapping for mana is
## the usual way it fires) and destroys it. Kudzu then HOPS: the choice is
## the dying land's CONTROLLER's, not Kudzu's controller's, it is optional
## ("may"), so a player may let the vine die with the land, and it reaches
## ANY land on the battlefield — including one the Kudzu player controls,
## which is how the victim gives the problem back.
##
## The new host is picked BEFORE the old one is destroyed, so the aura
## never spends a moment orphaned where a state-based action could sweep
## it; the move itself is MtgGame.move_aura, which re-attaches without a
## zone change (CR 701.3) so nothing re-triggers.
##
## A land its controller has already tapped for mana is spent either way,
## which is why the vine wants a fresh, untapped land next.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Kudzu", "{1}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(land_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _strangle,
			"When enchanted land becomes tapped, destroy it. That land's controller may attach this Aura to a land of their choice.",
			_host_tapped)) \
		.oracle("Enchant land\n"
			+ "When enchanted land becomes tapped, destroy it. That land's controller may "
			+ "attach this Aura to a land of their choice.")


static func _host_tapped(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var tapped: CardInstance = event.data["instance"]
	return tapped != null and source.attached_to == tapped.id


## Untapped lands first, then anything: an already-tapped land is spent for
## the turn anyway, so a player moving the vine puts it on a land they have
## not used yet only when nothing better is left.
static func _tapped_first(a: CardInstance, b: CardInstance) -> bool:
	return int(a.tapped) > int(b.tapped)


static func _strangle(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var host: CardInstance = event.data["instance"]
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := host.controller_id
	# "attach this Aura to A LAND OF THEIR CHOICE" — any land on the
	# battlefield, not merely one they control. Handing the vine back to the
	# Kudzu player's own land is the defence the printed card offers, and
	# the 1997 prompt (`@KUDZU`, "Kudzu triggering...Select target land.")
	# carries no ownership qualifier either.
	var candidates: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if inst.is_land() and inst != host:
			candidates.append(inst)
	candidates.sort_custom(_tapped_first)
	var next_host: CardInstance = null
	if source.zone == Mtg.Zone.BATTLEFIELD and not candidates.is_empty() \
			and game.agents[pid].choose_yes_no(game, pid,
				"Move %s to another of your lands?" % source.data.card_name, true):
		next_host = game.agents[pid].choose_card(game, pid, candidates,
			"Choose a land for %s" % source.data.card_name)
		if next_host == null or not candidates.has(next_host):
			next_host = candidates[0]
	if next_host != null:
		game.move_aura(source, next_host)
	game.destroy(host)
