# PvP diagnostics preview

Install the ZIP by extracting its `NamesInRed/` folder into
`_forever_/Interface/AddOns/`. The AddOns list shows **Names in Red (Debug)**.
This is a temporary build for Forever 1.60.1. Collection starts at addon load
and works during ordinary play.

- `/nirdebug` prints the retained record count and session number.
- `/nirdebug sample` adds a snapshot of the current target and mouseover,
  HK totals and, in an instanced PvP match, the local scoreboard row.
- Log out normally or use `/reload` to flush SavedVariables. Open
  `_forever_/WTF/Account/<account>/<realm>/<character>/SavedVariables/NamesInRed.lua`
  and inspect `NamesInRedDebugDB`. The file contains the complete retained
  diagnostic data. The filename is shared with the regular ledger.
- Send the file to the project owner privately for analysis. The data can
  include character names, GUIDs and raw honor messages.

The last 250 rows are retained independently per character. Each row has a
session and timestamp. The initial row records the client build, locale and
event registration results. The preview captures the honor channel, HK
changes, standalone PARTY_KILL, match completion, and the local death recap
immediately and after 0.3, 1 and 2 seconds. Local deaths and party kills may
also include PvE so the same cases can act as controls. Consecutive death
probes are scoped to their own sequence. Field status distinguishes
`readable`, `absent`, `secret`, restricted tables, and API failures.
Recap rows are bounded to 32 per sample and include the original event count.

Record these scenarios when they happen:

1. Get hit by two enemies before dying. If a third enemy heals them, note that
   separately and sample the target while visible when practical.
2. Make an opposing player die with and without landing the finishing blow.
   Repeat on a battleground and note when two enemies die close together.
3. Try one PvE death as a control. Compare repeated recap reads to identify
   stale or delayed rows.

This preview collects evidence for multi-attacker and assist attribution.
The diagnostic data lives in a separate SavedVariables table. Ordinary
rival counters receive no automatic writes.
