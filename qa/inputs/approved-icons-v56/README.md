# Approved icon source transfer

Source: owner-private 5525 specification wiki v56, commit f9ffdc99f01122c1530bd6c872d875b7147cf353. Read with existing authorized Sites access; no sharing change. Added only to the authorized ui/feedback-261021 review branch.

Archive: 5525-approved-icons-v56-transfer.tar.gz
Bytes: 4495025
SHA-256: 38548b839f7b1fe8f11f98fb130bad7289b316a19f6b16ee6a81d2d0cf07be93

Contents: manifest.json with 50 equipment and 23 skill mappings, exact sprite crops and levels, 56 asset hashes; equipment.html, skills (HTML), style.css, original assets, and user-approved/unarmed.png. No PDFs or credentials. Images are unchanged originals. Verify archive SHA-256, extract to a separate directory, then verify all manifest asset hashes before implementation.

The approved fist image is user-approved/unarmed.png, 6802 bytes, SHA-256 bd0be9ffa4b4626f509eb7a2ecf30ed8aad43623a55eea91ddc1da0c2487605c. The v56 wiki had no equipment image for fist/fist-1/fist-2; its itemUse skill icon is separate. Follow current user-approved virtual-fist gameplay rules rather than treating historical v56 equipment rows as new gameplay authority.

Skill icons: legSweep, scout, mage and porter have dedicated approved sprites. Other 19 skills retain skill + temporary badge. legSweep and itemUse have numeric 1/2/3 variants; scout and archer display 1 only. Preserve source aspect ratios and overlay semantics. Do not infer new stats or dedicated icons.
