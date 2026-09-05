extends CardScript
## Pyramids — {6} — Artifact — (arn, rare)
## Oracle: {2}: Choose one —
##         • Destroy target Aura attached to a land.
##         • The next time target land would be destroyed this turn, remove
##           all damage marked on it instead.
##
## Implementation: two ACTIVATED ABILITIES rather than one modal one — the
## engine's modes belong to spells (CardData.modes), and two abilities is
## how a player picks between them anyway: the menu shows both, and each
## takes its own target, which is what the printed card needs (one aims at
## an Aura, the other at a land).
##
## The second mode is a DESTRUCTION SHIELD (CardInstance.destruction_shields,
## new) and deliberately NOT a regeneration shield: regenerating taps the
## permanent and pulls it out of combat (CR 701.15a), and the Pyramids do
## neither — a saved land is still untapped and still making mana. It is
## also not regeneration for the rules, so "can't be regenerated" does not
## turn it off.
##
## `@PYRAMIDS`, `Program/promptsX1.txt:320`, has four strings and names both
## halves: `Select land.` / `Illegal target (not dying).` / `Select land
## enchanting enchantment.` / `Illegal target (not enchanting a land).`


func build() -> CardData:
	return CardData.new("Pyramids", "{6}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{2}", false, [
				DestroyEffect.new(_land_aura_spec())],
			"{2}: Destroy target Aura attached to a land.")) \
		.activated(ActivatedAbility.new("{2}", false, [ShieldEffect.new()],
			"{2}: The next time target land would be destroyed this turn, remove all damage marked on it instead.")) \
		.oracle("{2}: Choose one —\n• Destroy target Aura attached to a land.\n"
			+ "• The next time target land would be destroyed this turn, remove all "
			+ "damage marked on it instead.")


## "Destroy target AURA ATTACHED TO A LAND": the host's type is part of the
## restriction, so it belongs in the TargetSpec (a game-aware predicate,
## since resolving `attached_to` needs the game). The 1997 prompt carries
## the refusal itself — `@PYRAMIDS`, `Program/promptsX1.txt`, "Illegal
## target (not enchanting a land)" — and mage-go filters with
## `IsAuraOnLand` (`cards/arabian/artifacts.go`). The host's LIVE type is
## read, so an animated land still counts and an Aura whose host stopped
## being a land no longer does.
static func _land_aura_spec() -> TargetSpec:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"Select land enchanting enchantment.")
	spec.with_game_filter(_aura_on_a_land)
	return spec


static func _aura_on_a_land(game: MtgGame, inst: CardInstance) -> bool:
	if not inst.data.is_aura() or inst.attached_to < 0:
		return false
	var host := game.find_instance(inst.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD and host.is_land()


class ShieldEffect extends EffectBase:
	func _init() -> void:
		# `@PYRAMIDS` entry 1, Program/promptsX1.txt:322.
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "Select land.",
			ShieldEffect._is_land)

	static func _is_land(inst: CardInstance) -> bool:
		return inst.is_land()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var land := game.find_instance(target.instance_id)
		if land == null or land.zone != Mtg.Zone.BATTLEFIELD:
			return
		land.destruction_shields += 1
		game.log_line("The Pyramids shelter %s" % land.data.card_name)

	func describe() -> String:
		return "the next destruction of target land is replaced"
