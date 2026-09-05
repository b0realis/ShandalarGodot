extends CardScript
## Gauntlets of Chaos — {5} — Artifact — (leg, rare)
## Oracle: {5}, Sacrifice this artifact: Exchange control of target
##         artifact, creature, or land you control and target permanent an
##         opponent controls that shares one of those types with it. If
##         those permanents are exchanged this way, destroy all Auras
##         attached to them.
##
## Implementation: TWO target slots, so both permanents are real targets —
## shroud protects either one and the trade fizzles if either leaves. One
## targeting effect owns one slot, so the pair is two effects: the first
## only holds the slot for the permanent you give away, and the second does
## the work, reading its sibling through MtgGame.current_targets().
##
## "That shares one of those types with it" is a TARGETING requirement
## stated relative to the first slot, and it is one: the second slot's
## spec carries a TargetSpec.sibling_filter, judged with the first slot's
## ref in hand as the ability is activated (CR 601.2c), so a mismatched
## pair — your land for their creature — is refused with the original's
## `Illegal target (type).` before any cost is paid, and the list of
## partners the second slot offers is narrowed by what the first names.
## The same relation is re-judged on resolution (CR 608.2b): a partner
## that stopped sharing a type is an illegal target then.
##
## The trade itself is MtgGame.exchange_control (CR 701.10) — all or
## nothing: an exchange with an illegal target on either side doesn't
## happen (the Switcheroo ruling), so a permanent that has left, or gained
## shroud, cannot leave the other one stranded on the wrong side of the
## table.


func build() -> CardData:
	var give := GiveEffect.new()
	return CardData.new("Gauntlets of Chaos", "{5}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{5}", false, [give, TakeEffect.new(give.target_spec)],
			"{5}, Sacrifice this artifact: Exchange control of target artifact, "
			+ "creature, or land you control and target permanent an opponent "
			+ "controls that shares one of those types with it.") \
			.with_sacrifice_cost()) \
		.oracle("{5}, Sacrifice this artifact: Exchange control of target artifact, "
			+ "creature, or land you control and target permanent an opponent "
			+ "controls that shares one of those types with it. If those permanents "
			+ "are exchanged this way, destroy all Auras attached to them.")


## The predicates, in one place so both slots read the same words.
class GauntletsFilters:
	static func tradable(inst: CardInstance) -> bool:
		return inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_creature() \
			or inst.is_land()

	static func yours(_game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return source == null or inst.controller_id == source.controller_id

	static func theirs(_game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return source == null or inst.controller_id != source.controller_id

	## "… that shares one of those types with it" — [param earlier] holds
	## the first slot's ref, the permanent being given away.
	static func shares_a_type_with_the_first(game: MtgGame, _source: CardInstance,
			candidate: TargetRef, earlier: Array) -> bool:
		var mine := game.find_instance(earlier[0].instance_id)
		var theirs := game.find_instance(candidate.instance_id)
		return mine != null and theirs != null and shares_a_type(mine, theirs)

	static func shares_a_type(a: CardInstance, b: CardInstance) -> bool:
		for t in [Mtg.CardType.ARTIFACT, Mtg.CardType.CREATURE, Mtg.CardType.LAND]:
			if a.is_type(t) and b.is_type(t):
				return true
		return false


## Slot 1: the permanent you give away. Targeting it is the whole point of
## this effect — the exchange happens in [TakeEffect], which is the only
## one of the pair that can see both slots.
class GiveEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact, creature, or land you control",
			GauntletsFilters.tradable) \
			.with_source_filter(GauntletsFilters.yours)

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass   # the slot is the effect; TakeEffect does the trading

	func describe() -> String:
		return "the artifact, creature, or land you give away"


## Slot 2: the opponent's permanent that shares a type with the first —
## and the exchange.
class TakeEffect extends EffectBase:
	## The first slot's spec, to re-check that permanent's legality on
	## resolution the way the engine checked it when the ability went on
	## the stack — the engine only drops ILLEGAL refs per effect, and this
	## effect's own ref is the opponent's permanent.
	var give_spec: TargetSpec

	func _init(p_give_spec: TargetSpec) -> void:
		give_spec = p_give_spec
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target permanent an opponent controls that shares one of those types with it",
			GauntletsFilters.tradable) \
			.with_source_filter(GauntletsFilters.theirs) \
			.with_sibling_filter(GauntletsFilters.shares_a_type_with_the_first,
				TargetSpec.WHY["type"])

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var slots := game.current_targets()
		if slots.size() < 2 or target == null:
			return
		var mine_ref: TargetRef = slots[0]
		var mine := game.find_instance(mine_ref.instance_id)
		var theirs := game.find_instance(target.instance_id)
		if mine == null or theirs == null:
			return
		# An exchange with an illegal target on either side doesn't happen
		# (CR 608.2b, the Switcheroo ruling): the one being given away is
		# re-judged here since only THIS effect's ref was re-judged by the
		# engine.
		if not give_spec.is_legal(game, mine_ref, source):
			game.log_line("Gauntlets of Chaos: %s is no longer a legal target"
				% mine.data.card_name)
			return
		if not game.exchange_control(mine, theirs):
			return
		# "If those permanents are exchanged this way, destroy all Auras
		# attached to them" — the Auras go only when the trade happened.
		for host in [mine, theirs]:
			for aura_id in host.attachments.duplicate():
				var aura := game.find_instance(aura_id)
				if aura != null and aura.zone == Mtg.Zone.BATTLEFIELD:
					game.destroy(aura)

	func describe() -> String:
		return "exchange control of the two targeted permanents"
