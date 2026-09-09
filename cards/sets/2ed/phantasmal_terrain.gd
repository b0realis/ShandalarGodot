extends CardScript
## Phantasmal Terrain — {U}{U} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant land
##         As this Aura enters, choose a basic land type.
##         Enchanted land is the chosen type.
##
## Implementation: Evil Presence with a chosen type. The choice is made as
## the aura enters and remembered in CardInstance.memory (which the engine
## clears when the aura leaves the battlefield), then applied by the same
## become_basic_land_type static.
##
## "As this Aura enters, choose a basic land type" is a REPLACEMENT effect
## (CR 614.1c): it is applied AS the Aura enters, uses no stack, and there
## is no moment at which the Aura is on the battlefield and the land is
## still what it was. So it lives in CardData.as_it_enters — the hook
## MtgGame._put_on_battlefield runs once the permanent is on the
## battlefield and its `attached_to` is set, but before state-based
## actions and before any ENTERS_BATTLEFIELD trigger sees it, and which
## recalculates straight afterwards to publish what the callback wrote.
##
## IT USED TO BE A TRIGGER (fixed 2026-09-09, the owner's playtest:
## *"If i cast phantasmal terrain on a land of opponent to convert to
## forest ... I dont get life when opponent taps this 'converted
## forest'"*). A trigger goes on the stack, so between the Aura arriving
## and the choice being made BOTH PLAYERS GOT PRIORITY over a land that
## was still its printed self: it tapped for its old colour, and a
## Lifetap watching for "a Forest an opponent controls becomes tapped"
## (CR 603.2 — a trigger is tested against the game state at the moment
## of the event) saw a Plains and paid nothing. The comment that stood
## here said the choice could not be made on arrival because an Aura's
## `attached_to` is only set afterwards; it is set at the top of
## _put_on_battlefield, before this hook runs, and the assertion was
## simply wrong.


const TYPES := ["plains", "island", "swamp", "mountain", "forest"]
const COLORS := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G]
const LABELS: Array[String] = ["Plains", "Island", "Swamp", "Mountain",
	"Forest"]


func build() -> CardData:
	return CardData.new("Phantasmal Terrain", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.as_it_enters(_name_the_type) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted land is the chosen basic land type.") \
			.changing_land_types()) \
		.oracle("Enchant land\nAs this Aura enters, choose a basic land type.\n"
			+ "Enchanted land is the chosen type.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


## The type a player would name: whichever the host's controller has least
## of, so the land they were counting on is the one that stops being it.
static func _choose(game: MtgGame, host: CardInstance) -> int:
	var counts := [0, 0, 0, 0, 0]
	for inst in game.all_battlefield():
		if inst == host or inst.controller_id != host.controller_id or not inst.is_land():
			continue
		for i in TYPES.size():
			if inst.has_subtype(TYPES[i]):
				counts[i] += 1
	var best := 0
	for i in TYPES.size():
		if counts[i] < counts[best]:
			best = i
	return best


## THE REPLACEMENT (CR 614.1c), run as the Aura arrives: by now it is
## attached, so the candidates can be judged against the host, and nothing
## has had priority over the land in its old state.
static func _name_the_type(game: MtgGame, source: CardInstance,
		_controller: int) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	source.memory["type"] = game.agents[pid].choose_option(game, pid,
		LABELS, "Choose a basic land type for %s" % source.data.card_name,
		_choose(game, host))


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	# The hint is the fallback for the one recalculation that runs BEFORE
	# the replacement above (MtgGame._put_on_battlefield recalculates once
	# on arrival and again after `as_enters`), and for an Aura put onto the
	# battlefield by a path that never ran it. Not cached either way: the
	# answer belongs to the player, not to a pass of the pipeline.
	var index: int = int(source.memory.get("type", _choose(game, host)))
	host.become_basic_land_type(TYPES[index], COLORS[index])
