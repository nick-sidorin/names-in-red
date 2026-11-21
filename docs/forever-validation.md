# Forever feasibility and validation

Source baseline: Forever 1.60.1 build 70959, interface 16001. The findings below
come from code review and published addon packages. Live behavior has yet to be
verified for Names in Red.

## Attribution

- **Incoming deaths.** Blizzard documents `PLAYER_DEAD` without a killer payload,
  and `C_DeathRecap.GetRecapEvents(recapID?)` without a documented row schema.
  Blizzard's death dialog calls `HasRecapEvents()` and the recap UI consumes
  `overkill`. HeadHunter reports that a 1.60.1.69913 probe saw source GUID, name,
  flags, and timestamps. Its code retries after death, accepts a recent hostile
  participant when the finisher cannot be identified, and can infer pet ownership.
  Warlords Forever's `Kills.lua` instead takes the first recap row. Neither
  fallback establishes that a hostile player landed the final blow. Probe row
  ordering, zero overkill, completeness, and freshness. Commit only a uniquely
  identified hostile player finisher from a fresh recap. Use bounded retries
  tied to that death, cancel stale callbacks, and ensure at most one write across
  event retries and reloads. Leave pet attribution out until ownership and credit
  can be proven.
- **Outgoing kills.** Blizzard's standalone `PARTY_KILL` provides attacker and
  target GUIDs and is marked `SecretWhenUnitIdentityRestricted`. Warlords Forever
  1.3.0 registers this event, checks readable GUIDs, and checks the attacker
  against the local player or their current pet. Test event delivery in world
  PvP and battlegrounds, both solo and grouped. Require readable evidence that
  the local player was the attacker and the target was an opposing player with
  resolvable identity. A party member's blow does not qualify. Treat pet credit
  as a separate product decision. The similarly named combat-log subevent is a
  separate route. Generated documentation flags `COMBAT_LOG_EVENT_UNFILTERED`
  as restricted; compatible addon authors report it is closed to addons.
- **Honor and scoreboards.** `PLAYER_PVP_KILLS_CHANGED` carries a unit token for
  the changed totals. It does not identify a victim. Honor chat can name a
  victim for shared credit and can also report unrelated honor. Killbook 0.2.0
  uses honor and observed deaths, with a delayed Feign Death check in
  `Detect.lua`. These signals cannot prove who landed a killing blow. The
  `PVPScoreInfo` schema exposes per-player totals, including killing blows and
  deaths. `UPDATE_BATTLEFIELD_SCORE` carries no pairwise record and the
  `GetScoreInfo*` APIs carry `SecretInActivePvPMatch`. Post-match totals can
  cross-check the test session, but cannot attribute any individual event.
- **Identity and display.** `UnitGUID` and `UnitName` can be secret under
  identity restrictions. Check accessibility before comparing, indexing, parsing,
  printing or persisting results, including nested fields of returned tables.
  Protected calls contain runtime errors only. Hide contextual counts when a
  unit cannot be matched safely. HeadHunter's probe describes recap names as
  given name plus realm, while Killbook handles scoreboard names that may
  contain a surname in multiple formats. Treat any delimiter or name-only match
  as ambiguous until tested. Compare readable player GUIDs across recap,
  `PARTY_KILL`, unit tokens, relogs and realm contexts before adopting them as
  persistent IDs. Keep display names separate from record IDs.

Sources:

- [Blizzard Forever UI and generated API, build 70959](https://github.com/Gethe/wow-ui-source/tree/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns)
- [HeadHunter ForeverDeaths.lua](https://github.com/GudaAddons/HeadHunter/blob/4b06580c25e623f725ffd97bcf985c4437bb2164/Detection/ForeverDeaths.lua)
- [Warlords Forever 1.3.0 source package](https://www.curseforge.com/wow/addons/warlords-forever/files/9560128)
- [Killbook 0.2.0 source package](https://www.curseforge.com/wow/addons/killbook/files/9636021)

## Live client checks

Record the full client build, addon commit, context, event delivery and field
accessibility. Use consented participants and redact character identifiers from
published evidence.

| Scenario | Expected criterion |
| --- | --- |
| One opposing player kills the local player in world PvP and in a battleground | Fresh recap associates a unique lethal row with the actual attacker |
| Several attackers, NPC or fall as finisher, pet or guardian, exact-lethal damage | No attribution to a recent attacker or guessed owner |
| Rapid deaths, release, resurrection and reload while dead | Old recap cannot count again or be applied to the next death |
| Solo and party kills, group member kill, pet kill, unrelated nearby death, Feign Death | Check `PARTY_KILL` delivery and accessibility for the local player and readable group members |
| Simultaneous deaths in an active battleground and final scoreboard | Compare totals and verify that a matching delta does not qualify as an individual kill |
| Target, mouseover and nameplate in/out of combat and across plate reuse | Match only the currently exposed unit; restricted or stale identity clears decorations |
| Cold login, reload, switch characters, logout and relog | Verify SavedVariables loading, persistence and isolation |

## Implementation sequence

1. Bootstrap the local ledger and CI. Storage accepts a resolved ID and keeps
   display name and totals separately. Per-character storage is provisional.
2. Probe attribution and identity in both PvP contexts before wiring any event
   into storage. Prefer direct killing blows and skip ambiguous encounters.
3. Add a small editable list. Start with one sortable table and two columns,
   zero totals for manual additions, and add/remove. Decide how a name-only
   manual entry can be linked without merging distinct players. Decide whether
   to offer explicit manual corrections and how to label them before storing any.
4. Add individually verified incoming and outgoing attribution paths. Leave an
   unsupported direction manual for now, subject to the manual-edit decision.
5. Append to the native GameTooltip, add a noninteractive Blizzard-style target
   badge, then test addon-owned decorations on exposed nameplates. Research each
   matching Blizzard component before choosing a template or native artwork.
   Check combat lockdown, frame reuse, Edit Mode and input. Show only nonzero
   icons and hide the display when both counters are zero.

## First live evidence

For the nameplate preview, Camelot places the raid marker left of the health
bar and the level on its right. BigDebuffs can attach side indicators outside
the visible bar or name. The first Names in Red preview used a side anchor.
The current preview centers the label directly above the name to keep the
counters close to the character name and leave room for higher overlays.
Check spacing with native raid markers, auras and other addons in Forever.
See the [Camelot level template](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.xml)
and [BigDebuffs attachment code](https://github.com/jordonwow/bigdebuffs/blob/38690ed9d782c01c137779b7998dbe905c740fda/BigDebuffs.lua#L1596-L1630).

### Open-world killing blows

A 1.60.1.70959 open-world sample on ruRU exposed both PARTY_KILL GUIDs in
combat. The attacker matched the local player and the victim matched an
attackable player on the target token. The HK total increased from 0 to 1
after 285 ms despite two change notifications. The honor message one second
after the blow awarded seven honor without naming a victim. The saved log
retained three sessions. This observation supports the direct world kill path
only. The preview adds an explicit opposing-faction requirement, which was
not captured by the earlier build. Validate this requirement in the next
live sample. Assists, recap coverage, and battleground attribution are pending.

Another ruRU sample confirmed a personal killing blow against an opposing
player. An unnamed nine-honor message followed 1.012 seconds after `PARTY_KILL`.
The same session also recorded an unnamed one-honor message before the fight.
`CHAT_MSG_COMBAT_HONOR_GAIN` exposes general chat metadata and no documented
victim identifier. The preview keeps the raw messages in diagnostics and does
not assign a reward to an encounter based on timing alone.

## Live death evidence and first UI

One open-world death on 1.60.1.70959 produced two PLAYER_DEAD notifications
108 ms apart. Both immediately exposed the same ten damage rows from one
hostile player, including readable GUID, display name, flags and a lethal hit
with 87 overkill. Later reads repeated the same lethal timestamp. The test
fixture reproduces this duplicate with synthetic identity and timestamps.

A later open-world group session exposed two different player finishing blows
with readable GUIDs, hostile player flags and positive overkill. Each death
produced two notifications with the same lethal timestamp. One recap also
contained another player and two creatures, and the other contained two
additional players. Replaying the four notifications through the updated
handler yielded two records with two and three hostile players respectively.
The finishing blow is checked separately from the other recent damage rows.
The attacker list is limited to readable hostile players in that recap.
The new card tooltip uses the native `GameTooltip`.

On the Forever 70959 source branch, `Blizzard_DeathRecap.lua` loads the event
array through `C_DeathRecap.GetRecapEvents` and uses `overkill` in its damage
display. Generated `UnitDocumentation.lua` documents that standalone
`PARTY_KILL` carries attacker and target GUIDs. Neither observation establishes
the entire participant roster. Falls, pet credit, participation on the outgoing
kill path and battleground coverage still need validation. The new card
tooltip has not been checked in the live client.

### Participant diagnostic preview

The 0.1.3-preview.1 build records a local combat sequence, group snapshots,
and readable target metadata at combat boundaries. After combat, it samples
Damage Done, Damage Taken, Enemy Damage Taken and Healing Done. A single
newly archived meter session takes precedence. A Current-session sample is
explicitly labeled as a fallback when a unique new archive is unavailable.
The capture is scoped to its combat sequence and is marked interrupted when
combat resumes before the read. Source and spell lists have bounded samples.
Secret, restricted and unavailable fields retain their read status.

The probe follows the supported APIs used by
`DamageMeterSessionWindowMixin:GetCombatSession`,
`DamageMeterSourceWindowMixin:GetCombatSessionSource` and the target fields
used by `DamageMeterEntry.lua` in Forever 70959. A target name in an
aggregate is evidence to inspect rather than automatic encounter attribution.
Compare both players' saves after a fight in a party and a fight outside it.
Have one attack while the other lands the finishing blow. This probe needs
live-client validation.

### Seeded full-battle cards

The 0.1.3-preview.2 cards use the existing book frames, text and world map
action. For class icons they use the native class sheet and UVs, following
`Blizzard_PVPMatch/PVPMatchTable.lua`. Class colors use the client's
`RAID_CLASS_COLORS` as in `Blizzard_FriendsFrame/Mainline/FriendsFrame.lua`.
The two-column roster and the time-ordered blow list are owned by Names in Red.
The test suite exercises card reuse across different roster sizes and verifies
that fixture removal preserves other saved records. Card rendering still
needs a Forever client check.

The reciprocal-kill fixture against Dargun ends with both sides dead and
has an unknown result. The Feralas 2 × 1 fixture records a team win after
the local player dies and an ally lands the final blow. In a complete
multi-opponent win, each opposing profile receives one win. Test one
confirmed loss and the incomplete Tanaris fixture as well.

The live observer uses `PARTY_KILL` and local death recap rows to assemble
a partial open-world record. Killing-blow identity can come from the player
or a readable party member. A short tail after leaving combat lets a nearby
teammate's finishing blow join the same record. A long gap after combat, a
world change or resurrection starts a fresh observation. Check missing targets, ghost state
and the timing of kills your group makes after you die.

The user's 70959 group log showed a session HK increase from four to five
317 ms after a readable player death credited to another attacker, followed
roughly one second after the kill by a localized honor message. The preview
correlates a single plausible player death with one session HK increment, using
`GetPVPSessionStats` and `PLAYER_PVP_KILLS_CHANGED`. Repeated notifications
are coalesced by the cumulative counter. For honor, it uses a single
`CHAT_MSG_COMBAT_HONOR_GAIN` delivery and the observed ruRU amount or a
numeric `CURRENCY_DISPLAY_UPDATE` for an honor currency. These events still
lack a shared victim identifier. Verify an isolated kill, simultaneous kills,
reward-only messages and secret data in the live client.

From preview.6 onward, a rival's linked cards open a full-width battle in
the same book. This follows the in-window detail transition in
`ProfessionsCraftingPageMixin:SelectRecipe` in `Blizzard_ProfessionsCrafting.lua`.
The Back control uses the native `UIPanelButtonTemplate` and `BACK` text as
in `Blizzard_ProfessionsCrafterOrderView.xml`. The chosen rival's highlight
uses the same `Professions_Recipe_Active` atlas as the book roster.
In Forever, check **Open skirmish** from Information and a scrolled rival
history, then **Back**. Include an old saved battle outside the latest 100
and a partial record. Check the selected highlight and localized button widths.

### Expanded evidence in 0.1.3-preview.3

The old preview captured kills, honor changes and death recaps. The next
preview added combat boundaries, party snapshots and post-combat meter data.
This preview adds visible player observations from target, mouseover and
ordinary nameplate events, plus readable target, pet, combat and death state.
The probe uses the unit tokens documented in Forever's
`NamePlateManagerDocumentation.lua` and `UnitDocumentation.lua`. It does not
read forbidden nameplates. Observations are candidates for investigation.
Visibility, a target change or a group entry alone does not prove participation.

Group and pet context is sampled around combat and readable kill events.
Group changes and damage-meter update IDs are recorded within the combat
window. The post-combat read probes deaths, interrupts and dispels alongside
the existing damage and healing categories when supported.
Observations are bounded to 32 readable contacts and eight previous states per
contact. Repeated flags are throttled. The first eight fully obscured kill
events in a combat are stored individually, with the total retained at combat
end. Protected fields remain unavailable. The collector is local and the
additional event coverage needs a check in the Forever client.

The UI uses the Forever Blizzard PortraitFrameTemplate,
UIPanelScrollFrameTemplate and UIPanelButtonTemplate, and a unit-only
TooltipDataProcessor post-call for GameTooltip. The minimap button follows
Azeroth Fitness's native tracking-border artwork and drag behavior.
Level, zone and local map coordinates are best-effort snapshots. Test layout,
scrolling, minimap dragging and tooltip refresh in the real client, including
hovering an item after a known unit and reopening the book after reload.

The revised book follows the title drag region in Azeroth Fitness
`UI.lua`, the art and divider in Forever's Camelot `CharacterFrame.xml`
and honor heading art in `PVPRankFrame.xml`. The manual outcome cards use
the selection glow and ring atlases used by No Quest Hints Forever
`Onboarding.lua`. Verify window movement with and without BlizzMove,
empty panes, both outcome choices, and closing the dialog via Cancel,
Escape, the close button, and the parent closing.

The profession-inspired revision reuses the background and row-state atlases
from `Blizzard_ProfessionsRecipeList.xml` and the generic recipe background
from `Blizzard_Professions.lua`. The book owns all row data and frames.
The add dialog uses `AutoCompleteEditBoxTemplate` with the mail recipient
filters in `MailFrame.xml` and leaves free-form entry available. Verify a known
character suggestion, Tab and arrow selection, Enter accepting a suggestion
before saving, Escape dismissing suggestions first, and an enemy name the
client does not suggest. Check both layouts with longer localized names.

The First Aid reference uses the specialized `Professions-Recipe-Background-FirstAid`
atlas, the recipe list background, the minimal scrolling track and the item slot
art. The overview uses the circular output icon's ring and mask without its item
scripts. Race portraits follow `GetRaceAtlas` based on readable player info by
GUID, then fall back to a class icon or a question mark. Test selected and
empty rosters, enough rivals to overflow, and records with and without identity
data. The compact add dialog uses the circular portrait ring and a restrained
ArtifactsFX-YellowRing selection glow. Check spacing and selected states in Forever.

Camelot's profession overrides in `Blizzard_ProfessionsFrame.lua` and
`Blizzard_ProfessionsCrafting.lua` replace the window background with
`Profession-Background-Overview`, hide the list NineSlice, and clear the
schematic NineSlice anchors. The book follows that treatment and uses the
recipe atlas for the right panel's ornamental frame.

The book uses the top band of Camelot's `Profession-Background-Template2`
atlas, including its lower edge. The details panel uses a plain recipe backdrop,
a proportional Engineering illustration with feathered edges in the lower right,
and the separate `common-insideframe` trim from Camelot's schematic XML. The portrait uses the
add dialog's circle mask and rim. UV insets remove the inventory bevel from
the fallback icon. Verify these surfaces in Forever.

The roster toolbar uses the professions search box and the native Friends
add icon. Check UTF-8 name filtering and clearing, selecting the first result,
and adding a manual rival while filtered. The native delete confirmation names
the selected rival and captures its ID when opened. Verify that cancel leaves
the record intact and accepting removes only that record, including when two
rivals share a display name.

The statistics section instantiates `ProfessionsReagentSlotBaseTemplate` in
`Blizzard_ProfessionsRecipeReagentSlotBase.xml`. Its `Button` inherits
`ProfessionsButtonTemplate` and the intrinsic `ItemButton` mask and layers.
It uses the ordinary reagent state from `SetModifyingRequired(false)`, the
native `SetItemButtonTexture` path, and `SetSlotQuality(Common)` for the
profession frame. The book supplies the icon asset and localized tooltip
without binding the button to an item or crafting transaction.

## Skirmish cards and the world map

The book uses `PanelTopTabButtonTemplate` from Forever
`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`. The tab textures are
bottom-anchored by `PanelTopTabButtonMixin:OnLoad`. The book places the tabs
above a sibling pane whose `common-insideframe` trim covers their lower edge.
The `transmog-tab-hl` strip follows the `SelectedHighlight` layer in
`TransmogWardrobeCollectionTabTemplate` and the selected-state handling in
`TransmogWardrobeCollectionTabMixin:SetTabSelected`. It draws above the pane
from a child frame anchored to the tab's bottom corners, so the span follows
the localized label width. The book uses a two-unit strip with its upper
edge meeting the tab's bottom baseline.
Initial sizing uses the same text-based `PanelTemplates_TabResize` as
`PanelTabButtonMixin:OnShow`. Check that the first open after a reload and
subsequent opens use the same compact widths.
The settings reference is `GameTab` and `AddOnsTab` in
`Blizzard_SettingsPanel.xml`. Their `MinimalTabTemplate` swaps to
`Options_Tab_Active_*` via `MinimalTabMixin:UpdateAtlas`. The book keeps its
three active `uiframe-activetab` slices and lowers their brightness.
Camelot's `SchematicFormCraftingTemplate` in
`Blizzard_ProfessionsRecipeSchematicForm.xml` uses that same rim on the BORDER
layer. The full right column uses the same `Professions-background-summarylist`
atlas as the roster and `Blizzard_ProfessionsRecipeList.xml`. The right
column underlay lives on the page's BACKGROUND layer. The inset reaches the
bottom of the book, with a red Delete control inside its upper-right corner.
The control follows `GearSetButtonTemplate`'s `DeleteButton` from Camelot
`PaperDollFrame.xml`, including the `UI-GroupLoot-Pass-Up` texture and hover
opacity. Check it on Information and confirm it is hidden on Skirmishes.
Delete confirmation uses the client's shared
`StaticPopupButtonTemplate` from `Blizzard_StaticPopup_Game/GameDialog.xml`.
The book fades the left side of its illustration into the recipe
background using the texture gradient API. Check that the upper rim is
continuous in both tab states and that the illustration has no visible seam
at its left edge, including at non-default UI scales.

History uses the same `ScrollFrameTemplate` as the roster, with cards reused
as the viewport scrolls. Check both tabs on 1.60.1 with empty, legacy, manual
and seeded histories. Scroll through a long history, then switch rivals while
scrolled.

Both skirmish card layouts use `CommonSquareIconButtonTemplate` from
`Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml`, including native
tooltips and click handling supplied by `UIButtonMixin`. Its icons come from
`WaypointLocationPinTemplate` and `UIPanelInfoButton`. The button frames are
32 units square with 16-unit icons. Center the icon at rest and restore that
center after `SquareIconButtonMixin:OnMouseUp`. The
header uses the square template's scaled four-unit inset to match the date-to-map
and map-to-information gaps. The compact action icons use a half-unit upward
adjustment, including after the native mouse-up handler. The full history
map button keeps the unshifted native center. Verify both at the same UI scale.
Both portraits use the profile's 64-unit ring and 24-unit level badge. The
center uses one team-result marker. Portrait skulls indicate recorded deaths
regardless of the result. Hover the markers and rebind the card to check
tooltip cleanup.
A local portrait with no saved race portrait uses `SetPortraitTexture`, as in Camelot's
`CharacterFrameMixin:UpdateCharacterModeTabPortrait`. Race portraits use the
`resetTexCoords` argument to `SetAtlas`. The compact rival portrait flips its
full atlas region horizontally with `SetTexCoord(1, 0, 0, 1)`, following
`Blizzard_OrderHallUI/Blizzard_OrderHallTalents.lua` where the same talent atlas
is drawn facing either way. Check the full crop in the profile and the compact
card, and click the same rival repeatedly to verify the direction.
Check that the skirmish score and reward columns have stable left edges and that the labels start at the same left edge when their
counts change from one to multiple digits.
`PVPMatchStyle.GetLocalPlayerFactionTheme` uses the first return from
`UnitFactionGroup("player")`. The skirmish cards use the same faction tag to
order the existing blue and red palette. Check both factions in the full and
compact cards. Include a win, a loss and the Borin fixture, where the timeline
records two deaths with an unknown team outcome. Verify that a card rebind clears
stale tooltips and that the map action remains available on mapped legacy cards.

For the map diamond, see `WaypointLocationDataProviderMixin:HandleClick` and
the MAPPIN slash command in
`Blizzard_SharedMapDataProviders/WaypointLocationDataProvider.lua`. The book
uses the command's waypoint flow, including `OpenMapToUserWaypoint` from
`Blizzard_WorldMap/Blizzard_WorldMap.lua`. Test with a seeded card from a
different zone. Check that the world map opens on that zone, places its
standard user pin at the saved coordinates and replaces any previous user
pin. The full card uses the same map pin button as the compact card, anchored
beside the timestamp. Check the common header centerline and the spacing in
the finishing-blow list. Check that the Skirmish History scrollbar is centered
in the gutter between the cards and the decorative frame. The roster count
always shows the participants in the card. A passive `UIPanelInfoButton` from
`SharedUIPanelTemplates.xml` shows
the coverage tooltip when `rosterComplete` is false or absent. Seed fixtures
set this flag explicitly. Converted one-death entries lack a complete roster
confirmation, so their displayed counts show the known participants.
For legacy cards the addon uses `C_Map.GetMapChildrenInfo` from
`Blizzard_APIDocumentationGenerated/MapDocumentation.lua` to index Azeroth's
zone maps by localized name. Check older Hillsbrad and Stranglethorn cards
like the owner's screenshots, plus an unresolved zone. Verify the saved
location through the map action and that a rejected waypoint leaves the book open.

Preview.4 uses one tinted `Professions-background-summarylist` texture from
`ProfessionsRecipeListTemplate` across the entire right side of the rival
book. The inset frame and translucent battlefield illustration are separate
layers. The roster hover uses the native quest list texture from
`QuestLogFrame.xml` with reduced intensity. The finishing blow marker reuses
`common-icon-forwardarrow` from `GamepadNextPageButtonTemplate`.

### Window ordering, sounds and minimap hint

Forever 70959 loads the Camelot `ProfessionsFrame` from
`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml`. The shared
`ProfessionsFrameBase` uses `PortraitFrameTemplate` with `toplevel=true`.
`ProfessionsMixin:OnShow` and `OnHide` play the two
`UI_PROFESSIONS_WINDOW_*` sound kits. The book uses the same portrait
template and sound kits in its own visibility handlers.

The book remains a movable, independent top-level frame and uses the
ordinary MEDIUM strata. The old DIALOG strata always drew above a MEDIUM
frame regardless of its level. DeModal's `HookMovable` sets the supported
profession window to top-level and raises it on show, while BlizzMove
supplies drag behavior for registered Blizzard frames. The book uses native
top-level ordering and raises its own frame when shown.

The minimap tooltip follows Azeroth Fitness's `Shortcut:Init` implementation
in `Minimap.lua`, using a left anchor, title and a three-line localized hint.
Check first open, reopen, Escape and the close button for one sound per
visibility change. With DeModal and BlizzMove, overlap the book and
Engineering, then click the visible part or header of each alternately.
Check that both remain open and the clicked panel comes to the front.

## AddOn settings and data reset

Use `Settings.RegisterVerticalLayoutCategory`, `RegisterProxySetting` and
`CreateCheckbox` from `Blizzard_Settings_Shared/Blizzard_Settings.lua`.
Use `CreateSettingsButtonInitializer` from `Blizzard_SettingControls.lua` for
both actions. `Settings.OpenToCategory` opens the registered category from
the minimap right-click. Confirm that left-click still opens the journal
and dragging only moves the shortcut. With a known rival present, toggle
each display setting independently, confirm the change on the visible UI and
reload to check persistence. Unit tooltip refresh uses
`GameTooltipDataMixin:RefreshDataNextUpdate` from `Blizzard_GameTooltip`.

The custom confirmation and copyable URL use `StaticPopup_Show` and
`GameDialogMixin:GetEditBox`. `LaunchURL` is restricted in the client's
`URLDocumentation.lua`. Test Cancel, Escape and then Reset data on a character
with seeded records and diagnostic rows. Check the empty journal and confirm
that the two display flags and minimap position persist. Check that diagnostic
recording resumes with new events. The support dialog should select the
project's Issues URL for copying.

## Cross-rival skirmish history

The outer navigation follows `UI:Build` and `UI:Show` in Azeroth Fitness
`UI.lua`, and the `ProfessionsOverviewTab` anchor in
`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml`. It uses
`LargeSideTabButtonTemplate` and the native
`SidePanelTabButtonMixin:SetCustomOnMouseUpHandler` and `SetChecked` handling.
The two pages share the main book window. Clicking a known opponent in the
journal opens their profile even with a previous search active. The journal
uses the same two-sided battle card for all records. Older one-death entries
show their recorded participants, finishing blow and map data with a partial
roster tooltip. Their original saved data remains in the ledger.

The journal displays at most 100 cards across the ledger. It preserves older
saved entries and uses a bounded sorted list and a viewport-sized frame pool.
New manually added entries use their recording time for ordering. Historic
manual entries without a timestamp follow dated ones.

In Forever, check both side tabs and their hover and selected states, drag to
the right screen edge, open the history with and without entries, scroll to
the bottom, switch back to an opponent from the history with a prior roster
search active, and verify map buttons in both views.

The Rivals tab uses the icon from `RosterTab` in
`Blizzard_Communities/CommunitiesFrame.xml`. Both side tabs retain the native
`common-sidetab-mask` and the icon treatment in
`SidePanelTabButtonMixin:UpdateIconInterior`.

The addon list, window portraits, minimap, statistics, cards, manual dialog,
tooltip and nameplate use the same transparent `CrossedSwords.tga`. Framed
icons keep their native anchors and masks; square and inline icons use
centered texture coordinates for their display size. Inline texture
coordinates follow the format used by `GuildRewards.lua`.
The minimap uses the `MiniMap-TrackingBorder` and backing from
`Shortcut:Init` in Azeroth Fitness `Minimap.lua`. The icon is centered in
the visible opening of the border, which is near (20, 19.5) in its 64 × 64
source texture. That opening was measured in the public texture extraction
`Gethe/wow-ui-textures@d23deaf8f44a7d280dc974a5c9d5321c013db59b`.
Like the First Aid window, the book sets its portrait through `SetPortraitToAsset`. This is the
path used by `ProfessionsMixin:Refresh` in `Blizzard_ProfessionsFrame.lua`.
The stock `PortraitFrameTemplate` controls the portrait and mask placement.
The branded portrait samples a 120 × 120 window of the 128 × 128 artwork.
The portrait crop samples two texels farther right and the statistics crops
sample one, after the owner reported a slight left skew in the statistics.
The minimap samples the same artwork in a 23.5-unit square centered on its
existing circle mask. The
stock mask, reagent frame and texture anchors remain native. Reference mode
uses the full native icon and restores the branded crops when it exits.
The main skull artwork is shared by the statistics, cards and manual dialog.
The small pink skull remains a distinct inline indicator.
Compare the header to First Aid and both statistics slots to reagent icons
in the live client at normal and reduced UI scales.

In the 0.0.54–0.0.59 previews, with an opponent's Information tab visible,
`/nirdebug icons` swaps the window
and statistics art for First Aid, Linen Cloth and Wool Cloth in the same
frames. The addon portrait backing is hidden in reference mode. Run it again
to restore addon art. The chat diagnostics report the
center differences between texture and mask or border regions in UI units.
The region bounds include atlas padding and do not measure the center of the
visible paint. Compare before and after in the same client session.
The owner's 0.0.54 comparison shows the First Aid drop in both title portraits
and Linen Cloth in both reagent slots at approximately the same relative
positions. The inline captures support a visual comparison, with an estimated
one-to-two-pixel uncertainty in locating the edges.
