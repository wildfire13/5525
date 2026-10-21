# 261021 GUI review candidate

Base: 4a6724f0a1184eade48f5c3b5574cd17c151a9a1. f71660a and e0018a6 are ancestors. No pre-existing edits or unmerged commits were overwritten. Main push awaits GUI approval.

## Implemented

- Battle target abilities displayed in the right panel; removed separate ability button/window and redundant consent/success/recipient text. Cover keeps intended target and actual recipient.
- HP bar drawn at feet; removed 味/敵 text while preserving defense indicator and team colors.
- Skill selection mark on individual skill, actual MP cost, targeting instruction, Cancel and skill-name Execute labels. Failure reasons remain.
- Inventory equipment drag uses a framed row preview. Drop validates source owner, inventory token, connection generation, page epoch and the exact target slot. Existing quote/consent flow commits only on approval; buttons remain.
- Shop products drag to party portrait. Consent includes cost and exact recipient, purchase enters inventory without equipping. Includes consumables. Filter is outside scroll content; existing purchases/trials remain.
- New fist purchases removed. Empty-hand virtual defaults already exist independently per hand; blocked offhand for two-handed weapons remains excluded. Battle item permission now also verifies a hand source when equipment metadata exists. Outside-battle item use remains unchanged. Description includes バトル中にもアイテムを使用できる.

## Pending material / policy

Excel libfile_85261559da108191b8039d5f94fa867b, fist libfile_c9d6f56583f48191b33e458ea52793c5 and approved icon package libfile_9453ad2fe8c48191bf93868a98b49606 each prepared successfully but the official transfer helper returned download failed (exit 1), no local file. No actual source pixels inspected. Implemented from explicit written requirements as authorized. No icon guessing or denied-archive bypass. Icon application is NOT complete.

User approved retirement/refund of old fist-1. Load first validates the original, then clones it and removes paid fists from inventory and actual equipment fields, refunding 100G per item. Rollback snapshots are migrated independently (not added to current funds). Empty hands become virtual fists; the old Lv2 effect is removed. Repeated load is idempotent because the paid item IDs no longer exist. Original input/save file is not overwritten; existing atomic save behavior is unchanged. Refund beyond the supported currency bound rejects the load without changing the source.

## Validation

Godot isolated import successful. Current regression suite plus feedback_261021 passed after updating three outdated expectations for removed confirmation text / new Execute label. New checks cover slot validity, two-handed left-slot rejection, second accessory slot, stale payload, consent purity/cancel, equip to chosen slot, purchase to chosen owner without equipping, duplicate purchase protection, consumables, skill marks/cost, inline abilities and skill cancellation.

Eight native scripts pass (including save-file atomicity and UI rule regressions): test_feedback_261021, test_feedback_261019, test_feedback_261019_input, test_shop_transactions, test_inventory_battle, test_two_handed, test_campaign_files, test_ui_feedback_rules. Old failure logs are retained in external QA evidence. Tests exercise drop acceptance and transaction callbacks; actual pointer dragging and visual quality require GUI review.

## Start and review

Use a separate checkout of the candidate, existing Godot 4.6.x, Node >=22, Python >=3.10 and Pillow. Set NATIVE5525_NODE/NATIVE5525_PYTHON if runtime discovery is needed. Use separate XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME directories on Linux. Do not touch user Windows profiles.

    godot --headless --editor --path godot --import --quit
    godot --path godot

Windows existing launcher: Start-5525.cmd. Load the supplied synthetic east.json for inventory/shop review, and battle-heal.json for combat review. Party portraits open status. Drag a held spear to left/right hand and a ring to accessory2; cancel first, then confirm. In shop drag a product to a portrait, cancel first then confirm inventory receipt. Check all three status tabs, portrait changes, long names, many inventory/product rows, FHD and resized windows, foot bars and target ability readability. Preserve the approved camera and window persistence behavior.

Run automated checks:

    python godot/tests/run_inventory_header_261020.py --evidence /absolute/path/outside/checkout
    node native/test_feedback_261021.cjs

Restore by closing the isolated verification copy and reopening the original. Never overlay a dirty working tree.

Reattached approved icon package libfile_3abe3a154c78819189f80ec71c6e9a1d was also attempted using its newly authorized exact reference. Preparation succeeded; official transfer returned download failed, exit 1, no file and no HTTP status. No further retries after the scope-denial notice. Icon integration remains blocked.
