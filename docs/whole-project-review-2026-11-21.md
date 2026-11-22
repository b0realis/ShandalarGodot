# Whole-project review — 2026-11-21

A review of the whole project as it stood at 0.70.4 (the day the places
plugins landed), not of a diff: what is wrong, and what makes a duel or the
adventure's map stutter. Its fixes are version 0.70.5. Each finding below
says what was wrong, what holds now, and the test that pins it.

The tests are `tests/unit/test_review_2026_11_21_{engine,adv,saves,sites}.gd`,
`tests/ui/test_review_2026_11_21_{duel,adv,adv_duels,lan,shell}.gd`,
`tools/test_review_2026_11_21_tools.py` and `Review20261121Test` in
`tools/test_adventure_plugin.py`; the changed and new members by file are in
`docs/CODE_MAP.md` under "0.70.5 (2026-11-22)".

## The rules engine

Tests: `tests/unit/test_review_2026_11_21_engine.gd`.

- **An attacker paid its own attack tax.** A Llanowar Elves tapped for
  Propaganda's {2} and still attacked. The attackers are tapped before the
  cost of attacking is paid (CR 508.1f–i), so a creature that taps to attack
  is no payer of that cost (`MtgGame.attack_tax_barred_payers`, handed to
  `can_afford_cost` and `try_pay` as `excluded`); a vigilant attacker, a
  creature staying home and every attacker under an attacks-without-tapping
  effect may pay. The computer's attack planning judges its budget the same
  way (`HomelandsTactics.affordable_attackers`).
  `test_an_attacker_cannot_tap_for_its_own_attack_tax`,
  `test_a_creature_staying_home_may_pay_the_attack_tax`,
  `test_the_barred_payers_are_the_attackers_that_tap`.
- **One creature could be declared as an attacker twice**, charged its
  attack cost twice and counted twice against an attacker limit.
  `declare_attackers` refuses a repeated id.
  `test_an_attacker_is_declared_once`.
- **A "when it dies this turn" watch ran in the middle of the departure.**
  A Reincarnation that raised the same Clone had it reset to a bare 0/0 by
  the rest of the move, and a creature dying in the same Wrath was not yet
  in the graveyard to be chosen. A watch whose creature died is now due
  (`MtgGame._due_death_watches`) and runs once the departure, and any batch
  of simultaneous ones, is complete (`_run_due_death_watches`, from
  `_move_to_graveyard`, `_release_departures` and `end_simultaneous`);
  outside a batch it still runs at once.
  `test_reincarnation_on_a_clone_brings_it_back_copying_anew`,
  `test_a_creature_dying_in_the_same_batch_can_be_raised`,
  `test_a_watch_outside_a_batch_still_runs_at_once`.
- **Two players' Jade Monoliths on one creature shared one destination**:
  the later activation took both sources' damage. Each booking keeps its
  own seat (`CardInstance.damage_redirect_tos`, `book_damage_redirect`,
  `damage_redirect_to_for`, `take_damage_redirect`). The metered point
  redirects (Personal Incarnation) keep a row per destination, oldest first
  (`damage_point_redirect_rows`, `MtgGame._divert_points_to`); points
  written without a row become the oldest row
  (`_adopt_loose_point_redirects`).
  `test_two_monolith_bookings_each_keep_their_own_destination`,
  `test_jade_monolith_books_its_controller`,
  `test_point_redirects_go_to_the_seat_that_booked_them`,
  `test_points_written_without_a_row_still_move`.
- **A once-a-turn count followed the ability's position.** A grant ending
  mid-turn shifts the abilities after it, and one then read its neighbor's
  count. The count is the ability's (`CardInstance.ability_use_key`: a
  printed ability's printed position, a granted one's grantor and text;
  read through `ability_uses_at` by the engine and the AI).
  `test_ability_uses_follow_the_ability_not_its_position`,
  `test_a_printed_ability_keeps_its_printed_position_as_key`.
- **The computer paid before it planned.** Life paid for mana (Channel)
  ahead of a plan that then failed left the life gone and the mana floating
  to burn; it now asks first whether the taps cover the spell with that
  mana counted as floating (`AiPlayer._plan_covers_with_floating`).
  `test_the_ai_plans_a_payment_with_mana_it_is_about_to_buy`. By the same
  rule `_buy_prevention` asks everything `pay_for_prevention` refuses for
  before it taps, and `_spend_on_packet` asks
  `ability_announce_refusal` before it pays for an activation.
- **Every resolution was probed over a whole-game snapshot** to learn
  whether it would ask a question. The pre-flight now lets a resolution
  through without its probe when it provably asks nothing
  (`MtgGame._resolution_asks_nothing`, `_data_is_inert_on_arrival`; the
  probe itself is `_preflight_probe`, the skips counted in
  `preflight_skips`). See *Known narrowings*.
  `test_a_plain_creature_spell_resolves_without_a_probe`,
  `test_a_spell_that_asks_is_still_probed_and_held`,
  `test_a_board_that_can_react_keeps_the_probe`,
  `test_the_shapes_that_are_never_skipped`.

## The duel screen

Tests: `tests/ui/test_review_2026_11_21_duel.gd`.

- **Every redraw freed and rebuilt every card on the table** (some twenty
  nodes a card), whatever had moved, and the card under the pointer lost
  its hover each time. A row is now a list of slots, each named by what
  decides its shape (`DuelScreen._slot_key`); `_lay_slots` keeps a slot
  whose name stands and has its cards read themselves afresh
  (`_redress_slot`, `_redress_card`), and builds only the others. A pile
  compares its own rows (`CardPile.redress`; `keeps_rows` for the stacked
  hand), and a fanned hand's raised card stays raised. Only this screen's
  own table: a screen built on it rebuilds as before
  (`_keeps_table_widgets`).
  `test_an_unchanged_card_keeps_its_widget_over_a_redraw`,
  `test_a_kept_table_reads_as_a_rebuilt_one_after_each_change`,
  `test_a_kept_card_does_not_hold_the_keys`,
  `test_a_pile_keeps_its_rows_until_its_shape_moves`.
- **The computer's dwell came on top of its thinking**, so its turn ran
  uneven: quick passes at one beat, a searched attack at that beat plus the
  search. The thinking is part of the dwell (`dwell_after_thinking`), and
  a decision that used up its frame (`SLOW_DECISION_SECONDS`) leaves its
  redraw to the next one (`redraws_next_frame`, `_redraw_after_decision`).
  `test_the_thinking_comes_off_the_dwell`,
  `test_a_slow_decision_is_drawn_on_the_next_frame_and_once`,
  `test_a_quick_decision_is_drawn_at_once`.
- **A redraw asked the engine the same question twice**: whether each
  card in hand is payable and each ability open, and again for the
  automatic pass at its end. The answers are kept for the length of one
  redraw (`_begin_verdicts` to `_end_verdicts`, `_activation_refusal_now`)
  and dropped whenever the engine moves.
  `test_the_verdicts_are_kept_for_one_redraw_only`,
  `test_a_redraw_asks_each_verdict_once`.
- **A card's picture was decoded on the drawing thread the first time it
  showed**, except in the adventure. Every duel hands both decks to
  `CardArtWarmer` as it sets up (`_warm_table_art`, `table_art_names`:
  the hands first, then the libraries a card each in turn).
  `test_the_duels_card_names_for_the_warmer`.
- **The large card was laid out again for the face it already showed.**
  `CardPreview.show_card` returns when nothing it lays out from has moved
  (`_face_key`), and the fits of a name, type line and rules text are kept
  by font, words, room and sizes (`_measure_cache`, at most
  `MEASURE_CACHE_CAP` entries).
  `test_the_large_card_is_not_laid_out_again_for_the_face_it_shows`,
  `test_a_kept_fit_equals_the_measured_one`.
- **The arrows and the number keys answered a question lying under
  another window** (Duel Options, the concede question, a reveal). They
  are that window's (`_window_above_selection`).
  `test_the_arrows_and_digits_stay_out_of_a_question_under_another_window`.
- **A click on a line did not end the arrows' walk**, so the next redraw
  handed the keys to the clicked line and a later Space answered it.
  `_note_choice_pointer`. `test_a_mouse_press_ends_the_arrows_walk`.
- **The tutor's picker could confirm twice in one frame** and park a
  second answer on the cast that had gone on. One confirm a window
  (`_on_search_confirmed`). `test_the_picker_confirms_once`.
- **The picker's selected row could not be let go**, so a keyboard or pad
  player could no longer fail to find. A second press on the selected row
  (the select key, or one plain click) lets it go
  (`DuelScreen.search_list_deselects`); a double click is still the OK.
  `test_the_pickers_selected_row_can_be_let_go`,
  `test_which_presses_let_the_pickers_row_go`.

## The adventure world

Tests: `tests/unit/test_review_2026_11_21_adv.gd`,
`tests/ui/test_review_2026_11_21_adv.gd`,
`tests/ui/test_review_2026_11_21_adv_duels.gd`.

- **All 4096 tiles were looked at for every tile the hero entered.**
  `ShandalarWorld.explore_around` looks only within `REACH` of the hero
  and counts a change only when new land was seen.
  `test_the_hero_sees_the_same_tiles_looking_only_near`.
- **The view, the small map and the map hashed the 40 KB page, and the
  sites, at every tick** to learn whether anything had changed. The world
  counts its writes instead: `ShandalarWorld.revision` (the page, a site's
  record, an encounter's) and `page_revision` (the page alone). A byte or a
  record written in place passes no setter, so its writer calls
  `touch_page()` or `touch()` after; two tests read the sources and hold
  every writer to it (the generators and the loader are exempt).
  `test_every_way_of_writing_the_page_moves_its_revision`,
  `test_every_file_that_writes_a_byte_of_the_page_touches_it`,
  `test_every_writer_of_a_site_s_or_an_encounter_s_record_touches_the_world`,
  `test_what_reads_the_sites_reads_them_again_when_one_is_written`,
  `test_the_small_map_draws_from_the_page_s_revision`.
- **The small map walked 51 × 51 tiles twice and cut some 350 polygons one
  by one at every tile entered.** It looks only at the tiles its box can
  hold (`WorldMinimap._tiles_in`) and draws the land as one mesh, a color
  asked once a terrain where no tile has a style of its own
  (`WorldTerrainPalette.uniform`).
  `test_a_plain_world_s_tiles_are_colored_by_their_terrain_alone`,
  `test_the_small_map_looks_only_at_the_tiles_its_box_can_hold`.
- **The map painted its land at every change of mode or journal line.**
  The land is a layer of its own, painted again only when what it shows
  changed (`WorldMap._look_at_land`, `_land_key`, `_paint_land`).
  `test_the_map_s_land_is_painted_once_not_at_every_look`.
- **A places plugin's place stood named on land not yet seen**, on the map
  and the small map. It shows once its tile is explored, as a town does
  (`WorldMinimap.place_shown`); a harbor and an island's castle as ever.
  `test_a_sites_plugin_s_place_shows_on_the_maps_only_once_seen`.
- **The Tasks' rows were compared with the whole adventure three times a
  tick.** Once: the guides' own look serves the history and the rows
  (`AdventureTasks.guide`, `_tracked`, counted in `looks`).
  `test_the_guides_look_at_the_adventure_once`.
- **The place under the pointer was described whole at every motion of the
  mouse** and every frame of a walk. It is kept while the pointer stays on
  its tile and asked anew for another tile, when the hero is shown anew,
  and every `HOVER_TICKS` ticks (`WorldScreen._place_hovered`).
  `test_the_place_under_the_pointer_is_described_once_a_tile`.
- **A line said in a dungeon repainted all 195 cells every frame** for its
  2.6 seconds. The board is painted again only while the line fades
  (`DungeonView.SAID_FADE`). `draw_order` is made once.
  `test_a_line_said_in_a_dungeon_repaints_the_board_only_as_it_fades`.
- **A plugin's pictures and its land's track were read, hashed and decoded
  on the drawing thread** as the first pane opened, the first marker was
  drawn or the hero first stepped onto the land; a marker's painted part
  was read back off the graphics card. `AdventurePlugins.warm` decodes
  them on a worker as the world opens (`WorldScreen._warm_the_plugins`)
  and the main thread keeps what is made for at most `WARM_BUDGET_US` a
  frame; a land's track not yet decoded is waited for in silence
  (`WorldDuels._tune_awaited`); a picture's painted part is measured as it
  is decoded (`AdventurePlugins.USED_RECT`). What a warm-up did not reach
  is made on demand, as before.
  `test_a_plugin_s_picture_is_measured_as_it_is_decoded`,
  `test_a_warm_up_keeps_the_same_picture_the_first_asking_would_make`.
- **Every meeting begun, lair entered and place left wrote the save on the
  drawing thread.** `AdventurePlayer.save_later` (and
  `WorldScreen.autosave_later`) hand this moment's adventure, a copy of
  its own, to a worker: the same bytes and the same `.bak` as `save`, one
  save at a time in the order asked. `finish_saves` writes all of them
  before any save is read, listed, deleted or written at once, before the
  world is left and before the game ends; a save that cannot be written is
  still said. Headless and in a browser the save is written at once
  (`saves_off_frame`).
  `test_saves_handed_over_are_written_in_order_with_the_same_backup`,
  `test_a_save_handed_over_is_the_bytes_a_save_at_once_writes`,
  `test_a_save_that_cannot_be_written_is_still_said`,
  `test_the_world_s_own_saves_go_to_a_worker_and_are_written_before_any_reading`.
- **A card list gave its pick twice** to a double click and Enter in one
  frame: two free cards at the tribute, two copies from the wise man. Once
  (`CardListPane.pick`). `test_a_card_list_gives_its_pick_once`.
- **M, F2 or F5 in the frame of a town's choice set aside a pane about to
  be freed**, and the town never came back. A pane that has given its
  choice is not on top (`VisitPane.leaving`, `WorldScreen.town_on_top`).
  `test_a_town_that_has_given_its_choice_is_not_set_aside`.
- **The window closed over a duel that was over saved nothing**, so a lost
  duel, and the card lost in it, was undone by the reload. Its result now
  stands: the duel is finished (`WorldDuels.finish_over`), its pane closed
  out (`close_out` of `EncounterPane`, `RuledTownPane`, `LairPane`,
  `DungeonPane`) and the world saved before the process ends
  (`WorldScreen._close_out_meeting`, `_close_out_lair`,
  `_close_out_board`). A duel still played saves nothing, as before, and
  nothing is saved that could be had twice (see *Known narrowings*).
  `test_the_window_closed_over_a_lost_duel_saves_the_loss`,
  `test_the_window_closed_mid_meeting_saves_nothing_as_before`,
  `test_a_win_whose_choice_waits_is_not_closed_out`, and the eight tests of
  `test_review_2026_11_21_adv_duels.gd` (a ruled town, a lair, a castle's
  or a dungeon's room).

## Saves

Tests: `tests/unit/test_review_2026_11_21_saves.gd`.

- **A save's id named its files unchecked**, so an id holding a path wrote
  and deleted outside the saves' folder. `AdventurePlayer.saved_id` keeps
  an id the game made and makes any other one of that shape, the same each
  time; the delete names files only by a plain id.
  `test_an_id_the_game_made_is_kept`,
  `test_an_id_with_a_path_never_leaves_the_saves_folder`,
  `test_the_lists_show_the_safe_id`.
- **A land whose dice was no number** was a script error on restore; it
  reads as the world's own (`AdventureRegions.restore`).
  `test_a_land_whose_dice_is_no_number_is_restored_whole`.
- **A region's name that was no word** was a script error; it is refused
  quietly (`AdventureRegions.saved_state`).
  `test_a_region_that_is_no_word_is_refused_quietly`.
- **A quest or an offer cut short** (no kind, no destination) was a script
  error at every town; it is none (`AdventurePlayer._quest_record`).
  `test_a_quest_cut_short_is_no_quest`.
- **A list of places cut short** left slots the game reads missing; it is
  filled to the 128 every world has, and another land's links are counted
  from cleaned places (`AdventureRegions.extra_links`).
  `test_a_list_of_places_cut_short_is_filled`,
  `test_another_lands_links_are_counted_from_cleaned_places`.
- **A value that is no switch under a name the installed plugin declares
  one refused the whole save.** Which names are switches is the installed
  version's word, so it is a change, not damage: the save opens and the
  land is held (`ExpansionContract.progress_broken`).
  `test_a_switch_that_is_no_switch_holds_the_land` (here and in
  `tests/unit/test_adventure_plugins_updates.gd`).
- **A save kept under another file name was listed and could not be
  exported**, and an older save renamed became a slot no adventure counted
  its own. Export finds it by the id it holds
  (`AdventureTransfer.renamed_of`), a save under its own name first; the
  slot migration goes by the save's id (`SaveSlots.migrate`).
  `test_an_adventure_kept_under_another_name_is_exported`,
  `test_a_save_by_its_own_name_comes_before_a_renamed_copy`,
  `test_an_older_save_renamed_becomes_a_slot_of_its_own_adventure`.

## Places plugins

Tests: `tests/unit/test_review_2026_11_21_sites.gd`.

- **A raised dungeon forgot its "where" when it moved**, and the hints
  that tell it again walk only 1997's fifteen slots: its Tasks row was
  gone after the first visit. A raised dungeon keeps its location clue as
  it moves and is told from the town nearest its new tile
  (`DungeonDoors.move`, `WorldClues.raised`); 1997's slots forget as ever,
  and the move draws the same dice.
  `test_a_raised_dungeon_keeps_its_where_as_it_moves`,
  `test_a_1997_dungeon_forgets_its_where_as_ever`,
  `test_the_move_draws_the_same_dice_with_and_without_the_set`.
- **Each tile asked read the land's saved places again**, a land's 4096
  tiles twice a button's press. They are read once
  (`DungeonDoors.kept_points`, handed to `takes_dungeon` and
  `expansion_place`), the answers the same.
  `test_the_kept_tiles_read_once_answer_as_each_tile_asked`,
  `test_a_raised_dungeon_stands_where_it_stood_before_the_review`.
- **A place put on a land later than its first day could stand under the
  hero, under Arzakon's portal or on a lair.** Those tiles are blocked
  (`AdventureSites.blocked_tiles`, `spot`'s `blocked`); a new campaign's
  places stand where they stood.
  `test_the_blocked_tiles_are_the_heros_the_portals_and_the_lairs`,
  `test_a_new_campaigns_places_stand_where_they_stood`,
  `test_a_place_put_on_the_land_later_keeps_off_the_hero_the_portal_and_a_lair`.
- **A damaged save's record of a raised dungeon was believed of any
  slot**: pointed at a castle or a 1997 dungeon it read "open" for good,
  and the place took its price for a dungeon it then never raised. A raised
  slot carries a mark (`WorldClues.RAISED`, `"<plugin>:<dungeon key>"`)
  and the record is believed only of a slot that says so
  (`DataSites.dungeon_index`); a 0.70.4 save's unmarked vault is still
  found and marked.
  `test_a_raised_slot_says_whose_it_is_and_the_save_keeps_it`,
  `test_a_damaged_record_pointing_at_a_castle_or_a_1997_dungeon_is_not_believed`,
  `test_a_slot_marked_another_dungeons_is_not_believed`,
  `test_a_0_70_4_saves_unmarked_vault_is_found_and_marked`,
  `test_on_an_island_an_unmarked_slot_is_the_vault_only_under_its_name`.

## LAN play

Tests: `tests/ui/test_review_2026_11_21_lan.gd`.

- **A guest's "abandon" died with its socket** when the SGManalink screen
  closed: the host dropped the connection before its packets, and the
  opponent waited out the whole reconnect grace over a duel already given
  up. A client leaving the tree polls its parting sockets until the host
  has closed them (`SgLocalClient.drain`); not for a host in the same
  process (`SgLocalServer.hosts_port`).
  `test_a_parting_clients_abandon_is_read_before_its_socket_goes`,
  `test_a_client_leaving_the_tree_waits_for_a_host_elsewhere_only`.
- **A seat could not concede while the other seat was away**: the locked
  table refused it, though the referee takes a concession then.
  `SgDuelView._send` lets a concession past that lock; a tournament hold
  still holds it.
  `test_a_seat_concedes_while_the_other_seat_is_away`,
  `test_a_tournament_hold_still_holds_a_concession`.
- **The host's card-transfer allowance refused a plan within the guest's
  own limits**: each chunk request cost a whole chunk of the byte
  allowance, so the 205th was refused. The bytes really sent are counted,
  and the requests beside them (`SgCardTransfer.MAX_REQUESTS`).
  `test_a_plan_of_many_two_chunk_cards_completes`,
  `test_requests_past_the_largest_plan_are_refused`.
- **Join in the Game Browser took the first open table of the name**,
  whichever row was clicked. The clicked row's table is joined
  (`SgLobby._pending_row`: its deck rule, deck and rules), else the first
  open one of the name, as before.
  `test_join_seats_the_player_at_the_row_clicked_when_names_repeat`,
  `test_a_join_that_knows_only_the_name_takes_the_first_open_table`.

## The shell and the deck builder

Tests: `tests/ui/test_review_2026_11_21_shell.gd`.

- **Asking to make the game portable made the `portable` folder**, and
  Cancel or a failed copy left it: the next start entered an empty or
  half-filled folder, the settings, decks and adventures seeming gone.
  Asking makes nothing (`PortableMode.can_hold`); a first copy is made in
  a `portable-making` folder beside it (`making_name`) and renamed once
  whole, and removed when it fails (`remove_made`). A portable folder
  already there is copied into and kept.
  `test_asking_makes_no_portable_folder_and_cancel_leaves_none`,
  `test_can_hold_probes_without_making_the_folder`,
  `test_a_first_copy_that_fails_leaves_no_portable_folder`,
  `test_a_copy_stopped_halfway_is_removed_and_never_the_portable_folder`,
  `test_a_first_copy_arrives_whole_under_the_portable_folder`,
  `test_a_portable_folder_already_there_is_copied_into_and_kept`.
- **Escape with the portable window up left Options**, and mid-copy
  dropped the restart. It is the window's Cancel, and nothing while the
  copy runs.
  `test_escape_closes_the_portable_window_and_stays_in_options`,
  `test_escape_is_swallowed_while_the_copy_runs`.
- **Closing the game's window from the adventure's deck builder went past
  the Extra Cards box** that Done and Exit game ask.
  `AdventureBuilder._on_window_close_request` asks as they do.
  `test_the_window_s_close_asks_about_extra_cards_as_done_does`,
  `test_the_window_s_close_keeps_the_deck_on_edit_deck`,
  `test_a_deck_within_the_rule_closes_at_once`,
  `test_a_builder_that_only_looks_closes_at_once`.
- **An adventure deck past what the builder holds** (200 different cards,
  500 in all) lost the rest unsaid when the builder was left. The copies
  it cannot show stay in their deck (`AdventureBuilder._beyond`,
  `write_back`) and the status line says so.
  `test_a_deck_past_what_the_builder_holds_keeps_every_card`,
  `test_an_ordinary_deck_has_nothing_beyond`.

## The tools

Tests: `Review20261121Test` in `tools/test_adventure_plugin.py` (the
authors' tool) and `tools/test_review_2026_11_21_tools.py` (the two shell
scripts; a stub stands in for Godot).

- **`art` unpacked a PNG whole**: a small file that would unpack to
  gigabytes is now inflated no further than its header's own size
  (`png_alpha`). `test_png_alpha_never_unpacks_more_than_the_picture`.
- **`compat` called a change that uses up an action compatible.** A free
  action that gains prices, and a price list made shorter, are warnings
  and exit 1; a longer list, other prices and an action made free stay
  notes. `test_compat_warns_when_a_save_may_find_an_action_used_up`.
- **An edit that was stopped left the plugin folder half written.**
  `_commit_edit` puts every file back when a write fails, the judgement
  fails or the run is interrupted; each file is written whole or not at
  all (`_write_whole`) and keeps its permissions, and a read-only file is
  left alone: the edit stops there and what was written is put back.
  `test_an_edit_that_is_stopped_puts_every_file_back`,
  `test_an_edit_leaves_a_read_only_file_alone`.
- **`add-place` wrote a picture key the schema then refused**: the key is
  the plugin's id, `_` and the place's id, 40 characters at most. It says
  so at once.
  `test_add_place_says_at_once_when_its_picture_key_would_be_too_long`.
- **`add-dungeon` wrote `{dungeon}` into its words**, which is the last
  dungeon raised on the land: another one's name as soon as a plugin has
  two. It writes the dungeon's own name.
  `test_add_dungeon_writes_each_dungeons_own_name`.
- **`walk` played a place on one land only**, so a pane behind
  `on_mainland` was never shown. A place on the mainland and the islands
  is walked once for each (`walk_lands`).
  `test_walk_plays_a_place_on_each_land_it_stands_on`.
- **`export` deleted the zip already in `--out` when the new one was
  refused.** The new zip is written and judged in a dotted folder of its
  own and replaces the old one only when the game takes it.
  `test_export_keeps_the_zip_already_there_when_the_new_one_is_refused`.
- **`run_tests.sh`: a deal that failed for a later shard** left the
  shards already started running for up to `SUITE_TIMEOUT`. They are
  stopped and waited for.
  `test_a_deal_that_fails_stops_the_shards_already_started`.
- **`tools/expansion_lab.sh`: a plugin copy that failed half-way** was
  never removed. A trap removes it however the run ends.
  `test_a_copy_that_fails_leaves_no_plugin_copy`,
  `test_the_trap_is_set_before_the_copy`.

## Known narrowings

- **The pre-flight skips its probe for one shape only**: a plain permanent
  spell (no Aura, no copy, no target, no X, no modes, no trigger, static
  or entry hook, not legendary or world, a creature with printed
  toughness above 0 and no counters) arriving on a board where nothing can
  react to an arrival (no static ability anywhere, no control effect, no
  listener for an arrival or a state check, no permanent with an entry or
  sacrifice hook). Every other resolution is probed as before.
- **`AdventureTasks.rows()` keeps its deep key**: each look still compares
  every land's sites and encounters with what the rows were made from. It
  is one look a tick now, not three.
- **A beaten wizard's card picks are not saved by a closed window.** The
  window closed while a castle's wizard is beaten and his picks still wait
  saves nothing of that win, as before, never half of it
  (`DungeonPane.close_out`). The same holds for a creature's duel won
  whose spoils wait for a choice (`EncounterPane.choice_waits`).
- **A LAN guest's abandon is waited for on the guest's side**: a client
  leaving the tree polls its parting sockets for at most 200 ms
  (`SgLocalClient.EXIT_DRAIN_MS`), blocking that long at the latest when
  the host does not close them.
