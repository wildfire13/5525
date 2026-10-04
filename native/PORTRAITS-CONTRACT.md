# Portrait integration contract (a51a773)

Worktree: `G:/Apps/CodexProjects/5525-images-work`, branch `portrait-images`.
No commits, distribution or launcher changes until parent integration QA.

- New `portraits.py`: `resolve_portrait(images, member)` returns a cached 48px
  Tk image (or None). Uses **member['id']**, never name, job or equipment;
  enemy units retain their original graphics. Plain image dictionaries remain compatible.
- `PortraitImages` subclasses dict so existing `images=` constructor sharing stays intact.
  Campaign, deployment, actual battle and shop trial share this same object.
- Existing files touched: `app.py` import and unit image lookup;
  `journey_app.py` import and deployment lookup; `campaign_app.py` initial image
  dictionary, save/load/restart hooks, toolbar dialog and shop selector portrait.
  No constructor signature changes, JS changes, equipment layout redesign or battle
  action/timing changes. Equipment owner: preserve the portrait above the shop selector.
- Native save extension `nativePortraits` at envelope top level is handled only by
  Python and stripped before the JS bridge. Old saves imply no custom portraits.
  Normalized transparent PNG copies live in `native/user-data/portraits`; the save
  also embeds the PNG bytes so moving saves / deleting source files is safe.
- Pillow is needed only for image import/load (JPEG and safe bounded decoding).
  Missing Pillow must not prevent ordinary game startup.

Final verification and detailed limits will be recorded in PORTRAITS.md.
