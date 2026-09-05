extends CardScript
## Raging River — {R}{R} — Enchantment — (2ed, rare)
## Oracle: Whenever one or more creatures you control attack, each
##         defending player divides all creatures without flying they
##         control into a "left" pile and a "right" pile. Then, for each
##         attacking creature you control, choose "left" or "right." That
##         creature can't be blocked this combat except by creatures with
##         flying and creatures in a pile with the chosen label.
##
## 1997 (Duel.hlp, "Raging River", Enchant World): "If you declare an
## attack, defending player assigns each of his or her creatures without
## flying to either the left or the right side of Raging River. Each such
## creature can be assigned to block only attacking creatures on that side
## of Raging River this combat. Whenever you declare an attacker, assign it
## to the left or right side of Raging River." Rulings: "your opponent
## assigns his or her creatures without flying before you begin declaring
## attackers"; "Once a creature is assigned to a side of the River, it
## remains on that side of the River for that combat, even if its
## controller changes. However, if it gains flying later, it can block
## creatures on either side"; "If a creature comes into play after the
## attack begins, it's not assigned to a side of the River, so it may block
## creatures attacking along either side"; "Creatures attacking as a band
## may be assigned individually to either side of the River. Any creature
## assigned to block a member of the band will block everything in the
## band, including those on the other side."
## Prompts (Program/promptsX1.txt `@RAGING_RIVER`): "Select blockers on
## this bank." / "attack on left bank." / "attack on right bank." The
## 1997 exe has the card (Magic-trace.c: card_raging_river,
## raging_river_helper, fx_raging_river_903, helper_raging_river1/2).
##
## Implementation (lifted 2026-09-02; was "combat re-arrangement" in
## docs/simplified-cards.md): the piles and the labels are worked out when
## the trigger resolves and remembered on the enchantment; a static
## ability then writes one block restriction per labelled attacker, so the
## whole thing rides the normal "can't be blocked except by …" machinery
## every other evasion card uses. BOTH divisions are the players' choices
## through the DecisionAgent funnel — the defender sorts each non-flyer
## onto a bank ("left bank" / "right bank"; the hint alternates so the
## default split is even, which is what the engine used to do on its own),
## then the attacking player picks a bank per attacker with the 1997
## labels ("attack on left bank." / "attack on right bank."; the hint is
## the smaller pile, the harder side to block, which was the engine's old
## pick). Oracle and Duel.hlp agree on the order (the defender first) and
## on flyers being on no bank and blocking either side; the two differ on
## a creature that arrives after the split — Oracle: it is in no pile, so
## it can't block a labelled attacker; 1997: "it may block creatures
## attacking along either side". Oracle is followed (this is the "except
## by creatures in a pile with the chosen label" wording). Banding is as
## the 1997 ruling says without extra code: a blocker on the right bank
## blocks a right-labelled band member and thereby the whole band.
##
## Sequencing note: Oracle's trigger fires on the attack, so the defender
## sorts AFTER seeing the attackers, where the 1997 game had them sort
## before (its ruling calls this "one of the few cases where anything
## happens after combat has begun but before attackers are declared").
## Oracle is followed; the attacking player still picks last.


func build() -> CardData:
	return CardData.new("Raging River", "{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _split_the_river,
			"Whenever one or more creatures you control attack, each defending player divides their non-flying creatures into a left and a right pile, and each attacker picks a side.",
			_my_attackers)) \
		.static_ability(StaticAbility.new(_apply_labels,
			"Attacking creatures can't be blocked except by flyers and creatures in the pile with the chosen label.")) \
		.oracle("Whenever one or more creatures you control attack, each defending player divides all creatures without flying they control into a \"left\" pile and a \"right\" pile. Then, for each attacking creature you control, choose \"left\" or \"right.\" That creature can't be blocked this combat except by creatures with flying and creatures in a pile with the chosen label.")


static func _my_attackers(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	for inst in event.data.get("attackers", []):
		if inst.controller_id == source.controller_id:
			return true
	return false


static func _split_the_river(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var controller := source.controller_id
	var defender := game.opponent_of(controller)
	var left: Array = []
	var right: Array = []
	# The defender's division, one question per creature without flying.
	# The hint alternates down their battlefield so the default piles come
	# out even (the engine's old split).
	var banks: Array[String] = ["left bank", "right bank"]
	var i := 0
	for inst in game.players[defender].battlefield:
		if not inst.is_creature() or inst.has_keyword(Mtg.Keyword.FLYING):
			continue
		var bank: int = game.agents[defender].choose_option(game, defender, banks,
			"Raging River: which bank for %s?" % inst.data.card_name, i % 2)
		if bank == 1:
			right.append(inst.id)
		else:
			left.append(inst.id)
		i += 1
	source.memory["left"] = left
	source.memory["right"] = right
	game.log_line("Raging River splits the defenders %d / %d" % [left.size(), right.size()])
	# Then the attacking player's label per attacker (`@RAGING_RIVER`
	# entries 2 and 3). The hint is the smaller pile — the harder side to
	# block, which was the engine's old pick for every attacker.
	var sides: Array[String] = ["attack on left bank.", "attack on right bank."]
	var hint := 0 if left.size() <= right.size() else 1
	var labels := {}
	for inst in event.data.get("attackers", []):
		if inst.controller_id != controller:
			continue
		var side: int = game.agents[controller].choose_option(game, controller, sides,
			"Raging River: %s attacks on which bank?" % inst.data.card_name, hint)
		labels[inst.id] = "right" if side == 1 else "left"
		game.log_line("%s attacks on the %s bank" % [inst.data.card_name, labels[inst.id]])
	source.memory["labels"] = labels
	game.recalculate()


static func _apply_labels(game: MtgGame, source: CardInstance) -> void:
	var labels: Dictionary = source.memory.get("labels", {})
	for attacker_id in labels:
		var attacker := game.find_instance(attacker_id)
		if attacker == null or attacker.zone != Mtg.Zone.BATTLEFIELD:
			continue
		if not game.combat.attackers.has(attacker_id):
			continue
		var pile: Array = source.memory.get(String(labels[attacker_id]), [])
		attacker.cur_block_restrictions.append({
			"desc": "flyers and the %s pile" % String(labels[attacker_id]),
			"filter": _in_pile.bind(pile),
		})


## Only flyers and members of the chosen pile may block.
static func _in_pile(blocker: CardInstance, pile: Array) -> bool:
	return blocker.has_keyword(Mtg.Keyword.FLYING) or pile.has(blocker.id)
