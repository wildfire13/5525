"""Cases and result contract shared by the FHD runner and its parent."""
import json

SUITES = [
    'mock_character_migration', 'character_ab_fixes', 'character_details_parity',
    'mock_shop_migration', 'mock_facility_migration', 'mock_facility_presentation',
    'facility_readability_polish', 'background_ui_polish', 'shop_entry_position',
    'mock_travel_regression', 'mock_journey_integration', 'mock_service_regression',
    'mock_deployment_regression', 'combat_b_ui', 'battle_feedback_261116', 'battle_selection_regression',
    'menu_exit_regression', 'quest_reward_display_regression',
    'standalone_quest_failure_regression', 'quest_modal_regression',
    'npc_meeting_regression', 'town_meeting_layout_regression', 'quest_decisions_regression', 'quest_aftermath_access_regression',
]

ERROR_KINDS = {"script-error", "engine-error", "assertion", "resource-leak", "timeout", "process-exit", "launch-error"}


def read_results(path, expected):
    try:
        rows = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return [], "missing-or-invalid-report"
    if not isinstance(rows, list):
        return [], "invalid-report"
    suites = []
    for index, row in enumerate(rows):
        if index >= len(expected) or not isinstance(row, dict) or row.get("name") != expected[index]:
            return suites, "unexpected-case"
        errors = row.get("errors")
        if (not isinstance(errors, list) or not all(isinstance(e, str) and e in ERROR_KINDS for e in errors)
                or type(row.get("exit")) is not int or type(row.get("passed")) is not bool
                or row["passed"] != (row["exit"] == 0 and not errors)):
            return suites, "invalid-case-result"
        suites.append({key: row[key] for key in ("name", "exit", "passed", "errors")})
    return suites, "" if len(suites) == len(expected) else "incomplete-report"
