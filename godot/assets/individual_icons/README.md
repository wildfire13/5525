# Individual equipment and skill icons

Runtime PNGs are unmodified 64×64 RGBA artwork. The technical manifest binds 42 equipment images to 47 existing item IDs and 19 images to existing skill IDs. Five accessory images are shared by their slot-1/slot-2 copies; those suffixes are not levels. [The technical CSV](../../../docs/individual-icons-mapping.csv) lists each target ID explicitly outside the Godot resource tree.

The four previously adopted skill images (heal, ambush, leg sweep, formation boost), the approved virtual fist, and existing level badge artwork remain in `approved_v56`. Empty slots do not receive an item image. No game definitions or equipment levels are introduced here.

`approved_v56/recipes.json` is the primary display route. The legacy equipment mapping points to the same runtime files. Individual artwork does not receive the previous temporary badge. Supported level badges are composed once at the top right, inside the final 64×64 canvas; unsupported skill levels retain the existing fallback.

Thin spears and the pincer symbol are shown with their existing names in small UI rows. Material and role recognition must be checked in the actual UI, separately from PNG validity. Raw generation images, transfer metadata, private research and source conversations are not part of this runtime package.

The older `tools/import_approved_icons.py` rebuilds the v56 baseline only. Do not use it alone to regenerate this package: this manifest, both mappings and the runtime recipes must stay synchronized. The integrity test checks that relationship.
