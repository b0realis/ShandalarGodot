class_name MpnDuelTable
extends DuelScreen
## [QoL] The real duel furniture, with no local game driver or action inputs.
## Only the rendering helpers are called. Missing MPN effects are not guessed.

var projection := MpnProjection.new()
var _built := false
var _hand_badges: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game = projection
	config = DuelConfig.new()
	config.panel_colors.assign(["blue", "red"])
	stops = PhaseStops.new() # don't display or edit the player's live phase stops
	_build_ui()
	_built = true
	# Strip every action callback installed by the duel furniture. Replay
	# cards are built later, with inspection callbacks only. No menu, pass,
	# concede, drag-to-play, transport action or duel-layout toggle can fire.
	_disconnect_actions(self)
	# THE SPELL CHAIN STILL FOLDS (0.50.65 bug campaign, k3-7): its band's
	# ▼ is a way of looking, not an action, and the strip above cut it
	# too — the gadget stood there and did nothing. The gadget and a left
	# click on the folded band (the window icon's job) come back; the
	# band's right-click menu does not, as no menu fires in a replay.
	_chain_gadget.pressed.connect(func() -> void:
		_set_chain_minimized(not _chain_minimized))
	_chain_head.gui_input.connect(_on_replay_chain_head_input)
	_chain_box.under_band_changed.connect(func(_count: int) -> void:
		_dress_chain_head())
	for control in [_situation_bar, _arrange_button, _expand_button, _log_button,
		_screen_options_button, _combat_window, _combat_bar, _window_icon]:
		if control != null: control.hide()
	for hand in _hand_rows: hand.hide()
	_flight.queue_free()
	_flight = null
	for pid in 2:
		var badge := OriginalDialog.button("", Vector2(190, 28))
		badge.z_index = 60
		badge.tooltip_text = "Only publicly revealed cards can be inspected."
		badge.pressed.connect(_show_public_hand.bind(pid))
		add_child(badge)
		_hand_badges.append(badge)
		_grave_icons[pid].gui_input.connect(_open_public_pile.bind(pid))
		_exile_icons[pid].gui_input.connect(_open_public_pile.bind(pid))
		_life_buttons[pid].resized.connect(_fit_life_panel.bind(pid))
	_arrows.hand_anchors = _hand_badges.duplicate()
	resized.connect(_fit_badges)
	_fit_badges.call_deferred()

## A left click on the folded band restores the chain (k3-7).
func _on_replay_chain_head_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _chain_minimized:
		_set_chain_minimized(false)

func _disconnect_actions(node: Node) -> void:
	for signal_info in node.get_signal_list():
		for connection in node.get_signal_connection_list(signal_info.name):
			var callback: Callable = connection.callable
			if callback.get_object() == self: node.disconnect(signal_info.name, callback)
	for child in node.get_children(): _disconnect_actions(child)

func present(state: Dictionary, headers: Dictionary) -> void:
	projection.ingest(state, headers)
	for pid in 2: config.player_names[pid] = projection.players[pid].player_name
	# A card shown at a later instant must never remain visible after rewind
	# or concealment. Full-screen inspection belongs to the same observation.
	_card_preview.show_back()
	if _fullscreen_card != null: _fullscreen_card.dismiss()
	_close_graveyard()
	_refresh()

func _refresh() -> void:
	if not _built or projection.observation.is_empty(): return
	for pid in 2:
		var row: Dictionary = projection.observation.players[pid]
		_life_buttons[pid].text = str(int(row.life))
		_life_buttons[pid].tooltip_text = config.player_names[pid]
		_fit_life_panel(pid)
		_poison_labels[pid].visible = row.has("poison") and int(row.poison) > 0
		_poison_labels[pid].text = str(int(row.get("poison", 0)))
		if _poison_marks.size() == 2 and _poison_marks[pid] != null:
			_poison_marks[pid].count = int(row.get("poison", 0))
		_lib_labels[pid].text = str(int(row.library))
		_dress_deck_stack(pid, int(row.library))
		_grave_labels[pid].text = str(game.players[pid].graveyard.size())
		_exile_labels[pid].text = str(game.players[pid].exile.size())
		for color in _mana_labels[pid]: _mana_labels[pid][color].text = str(game.players[pid].mana_pool.total_of(color))
		_hand_badges[pid].text = "%s · Hand: %d" % [config.player_names[pid].left(24), int(row.hand)]
		_hand_badges[pid].tooltip_text = "Hand: %d cards. %d publicly visible. Click to inspect public cards only." % [int(row.hand), game.players[pid].hand.size()]
		_rebuild_field(pid)
	if _phase_bar != null:
		_phase_bar.visible = projection.observation.step in ["untap", "upkeep", "draw", "main1", "combat_begin", "declare_attackers", "declare_blockers", "first_strike_damage", "combat_damage", "combat_end", "main2", "end", "cleanup"]
		_phase_bar.set_state(PhaseStops.half_for_seat(game.active_player, 0), _phase_icon_slot(game.current_step()))
	_rebuild_stack()
	_update_arrows()
	_fit_badges.call_deferred()

func _fit_badges() -> void:
	if _hand_badges.size() != 2: return
	var area := get_global_transform().affine_inverse() * _board_area()
	for pid in 2:
		_hand_badges[pid].position = Vector2(area.position.x + 12,
			area.position.y + (area.size.y * 0.5 if pid == 0 else 0.0) + 8)

func _make_card(inst: CardInstance, _chain_item: StackItem = null) -> MiniCard:
	# No game argument: MiniCard cannot infer untap permissions, targeting
	# legality or other unrecorded rules from this partial observation.
	var card := MiniCard.new(inst)
	card.face_down = inst.face_down
	_observed_cues(card)
	if _chain_item != null: card.set_meta("chain_ability_id", _chain_item.id)
	card.set_highlight(MiniCard.Highlight.COMMITTED if game.combat.attackers.has(inst.id) or game.combat.blocks.has(inst.id) else MiniCard.Highlight.NONE)
	card.pressed.connect(_on_card_clicked.bind(inst))
	card.mouse_entered.connect(_on_card_clicked.bind(inst))
	return card

func _flush_pile(container: Container, cards: Array) -> void:
	# Keep the standard card/pile geometry, but never arm drag-to-play.
	if cards.is_empty(): return
	if cards.size() == 1:
		container.add_child(_make_widget(cards[0]))
		return
	var pile := CardPile.new()
	pile.preview = _card_preview
	pile.framed = true
	pile.populate(cards, false, _on_card_clicked, _highlight_for)
	_limit_pile_cues(pile)
	container.add_child(pile)

func _observed_cues(card: MiniCard) -> void:
	# Sickness, untap restrictions and indestructibility are not recorded.
	# A damage total alone cannot establish whether a creature is dying.
	card.omitted_states.assign([MiniCard.State.WILL_UNTAP,
		MiniCard.State.DYING, MiniCard.State.SUMMONING_SICK])
	card.refresh()

func _limit_pile_cues(node: Node) -> void:
	if node is MiniCard: _observed_cues(node)
	for child in node.get_children(): _limit_pile_cues(child)

func _on_card_clicked(inst: CardInstance) -> void:
	if inst == null or inst.face_down: _card_preview.show_back()
	else: _card_preview.show_card(inst)

func _on_chain_ability_clicked(item: StackItem) -> void:
	_on_card_clicked(item.card)

func _on_graveyard_card(inst: CardInstance) -> void:
	_on_card_clicked(inst)

func _show_public_hand(pid: int) -> void:
	var dialog := OriginalDialog.create(config.player_names[pid] + " — public cards", Vector2(560, 360))
	dialog.set_as_top_level(true)
	var text := OriginalDialog.label("Unrevealed cards are not recorded. Library positions and hand order are not reconstructed.", 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.body().add_child(text)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.body().add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for zone in [game.players[pid].hand, game.players[pid].library]:
		for card in zone:
			var button := OriginalDialog.button("%s (%s)" % [card.data.card_name, "hand" if card.zone == Mtg.Zone.HAND else "library"], Vector2(420, 30))
			button.pressed.connect(func() -> void:
				_on_card_clicked(card)
				dialog.dismiss())
			list.add_child(button)
	dialog.add_button("Close").pressed.connect(dialog.dismiss)
	dialog.set_meta("mpn_inspection", true)
	add_child(dialog)

func _open_public_pile(event: InputEvent, pid: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_grave_pile_clicked(pid)

func _open_graveyard(pid: int) -> void:
	if _grave_view == null:
		_grave_view = GraveyardView.new()
		# This view positions shelves in global coordinates. Keep inspection
		# at native scale even when the table is fitted above the toolbar.
		_grave_view.set_as_top_level(true)
		_grave_view.card_picked.connect(_on_graveyard_card)
		_grave_view.dismissed.connect(_close_graveyard)
		add_child(_grave_view)
		_grave_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		get_viewport().size_changed.connect(_refit_graveyard_soon)
	_grave_view.preview = _card_preview
	_grave_view.reset_paging()
	_grave_open_pile = pid
	_grave_view.show()
	_grave_view.opened()
	_card_preview.z_index = _grave_view.z_index + 1
	_repopulate_graveyard()

func _repopulate_graveyard() -> void:
	if _grave_view == null or not _grave_view.visible: return
	_grave_view.position = Vector2.ZERO
	_grave_view.size = get_viewport_rect().size
	_grave_view.board_area = _board_area()
	_grave_view.populate(game, -1) # neutral observer; no playable/legal callbacks

func dismiss_inspection() -> void:
	if _fullscreen_card != null: _fullscreen_card.dismiss()
	for child in get_children():
		if child.has_meta("mpn_inspection"): child.queue_free()
	_close_graveyard()

func inspection_open() -> bool:
	if graveyard_is_open() or _fullscreen_card.is_open(): return true
	for child in get_children():
		if child.has_meta("mpn_inspection") and not child.is_queued_for_deletion(): return true
	return false

# Read-only rendering never schedules or advances a live game. These are
# also defensive guards for inherited delayed layout/inspection callbacks.
func _drive_advance() -> void: pass
func _maybe_schedule_ai() -> void: pass
func _on_control(_event: InputEvent) -> void: pass
func _on_done() -> void: pass
func _on_pass() -> void: pass
func _on_cancel() -> void: pass
func _on_card_look(_event: InputEvent, _widget: MiniCard, _inst: CardInstance) -> void: pass
func _on_chain_band_input(_event: InputEvent, _band: Control) -> void: pass
func _is_human(_pid: int) -> bool: return false
func _pile_card_playable(_seat: int, _inst: CardInstance) -> bool: return false
func _highlight_for(_inst: CardInstance) -> int: return MiniCard.Highlight.NONE
