"""Ordered checks shared by the legacy UI runner and CI shards."""

ASSET_CHECKS = (
    ('event_voice_assets', 'node', 'native/test_event_voice_integration.cjs'),
    ('facility_asset_integrity', 'python', 'godot/tests/facility_asset_integrity.py'),
    ('individual_icons_integrity', 'python', 'godot/tests/individual_icons_integrity.py'),
)

GODOT_SUITES = (
    'event_voices_regression',
    'facility_art_261021',
    'hover_regression',
    'hover_lifetime_regression',
    'icons_approved_261021',
    'feedback_261021',
    'inventory_header_261020',
    'status_layout_lifecycle',
    'status_empty_inventory',
    'feedback_261019_3',
    'feedback_261019_2',
    'feedback_261019_input',
    'guild_regression',
    'inventory_regression',
    'ui_feedback2_20261016',
    'ui_feedback2_20261017',
    'ui_feedback_20261016',
    'shop_rows_regression',
    'shop_feedback30',
    'trade_feedback_261111',
    'owned_equipment_regression',
    'frontend_smoke',
    'ui_preferences_restart',
    'brushup_formation_regression',
    'brushup_comparison_regression',
    'facility_npc_regression',
    'research2_descriptions',
    'text_cleanup_regression',
    'battle_selection_regression',
    'inventory_context_regression',
    'window_resize_regression',
    'battle_layout_f2',
    'inventory_short_window_regression',
    'equipment_hover_f4',
    'skill_effect_regression',
    'ui_p3_drag_regression',
    'turn_order_keyboard_regression',
    'deployment_start_regression',
    'guard_visibility_regression',
    'individual_icons_regression',
    'audio_options_regression',
    'feedback_backdrops_regression',
    'loading_screen_check',
    'results_regression',
    'painted_vfx_regression',
    'vfx_expansion_regression',
    'facility_feedback2_regression',
    'feedback2_guild_regression',
    'deployment_drag_regression',
    'feedback2_party_strip_regression',
    'native_file_dialog',
    'feedback3_guild_regression',
    'feedback3_speech_regression',
    'speech_tail_regression',
    'status_footer_stability',
    'debug_window_check',
    'debug_log_accuracy',
    'debug_store_regression',
    'debug_store_teardown',
    'inn_feedback3_regression',
    'quest_board_feedback3',
    'warehouse_regression',
    'updateplan_regression',
)


def suite_checks(name):
    """Return (result name, phase) in execution order within one profile."""
    if name == 'ui_preferences_restart':
        return [(name + '_write', 'write'), (name + '_read', 'read')]
    return [(name, '')]


def check_groups():
    groups = [[name] for name, _, _ in ASSET_CHECKS]
    groups.extend([result for result, _ in suite_checks(name)] for name in GODOT_SUITES)
    return groups
