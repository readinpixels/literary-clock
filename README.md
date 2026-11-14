# Literary Clock for KOReader

A KOReader plugin that tells the time with a line from a book that mentions
it, as a module for the home screens of
[Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin) and
[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin).

> At **six minutes past midnight**, death relieved the sufferer.
>
> *West of Hell's Fringe*, Glenn Shirley

> **Pre-release.** Tested on a Kobo Clara BW with Bookshelf and SimpleUI.
> If something looks off on your device, please open an issue with your
> e-reader model and a photo.

## How it works

- Every minute the card shows a quote for that minute, with the time in bold
  and the title and author underneath.
- When a minute has several quotes, it picks one that is readable in the
  card, and the choice changes from day to day.
- The quote fills the card at the largest font size that fits, or uses a
  fixed size if you prefer.
- Works offline: the quotes ship with the plugin.

The clock updates only while the home screen is on. When the e-reader goes
to sleep its processor stops, so a clock on the sleep screen would stay on
the minute you switched it off.

## Install

Copy the `literaryclock.koplugin` folder into KOReader's `plugins` folder and
restart KOReader.

- **Bookshelf**: add *Literary Clock* from the module picker (category
  *Time*). Bookshelf finds the module by itself.
- **SimpleUI**: add *Literary Clock* from the module list (category
  *Extras*).

## Settings

Long-press the card (Bookshelf) or open the module's settings (SimpleUI):

- **Safe for work quotes only** (on by default): skips the quotes the dataset
  marks as not safe for work. With it on, 31 minutes of the day have no quote
  (see below).
- **Show title and author**.
- **Font size**: *adaptive* (default) fills the card at the largest size that
  fits; *fixed* uses the same size on every card (16 by default, from 8 to
  48). With a fixed size, a quote too long for the card is cut short with an
  ellipsis: pick a large size at your own risk.
- **Font**: Noto Serif by default, or any font installed in KOReader,
  including the ones you add to its fonts folder (on a Kobo, for example,
  `.adds/koreader/fonts` or `fonts` at the root of the device). Symbol fonts
  and fonts without Latin letters are left out. A family without a bold file
  is emboldened by KOReader; one without an italic file stays upright.
- **Time style**: how the time is set off from the rest of the quote: bold
  (default), bold italic, italic, or plain (useful with a colour).
- **Time colour** (colour screens only): the text colour (default) or one of
  eleven colours chosen to stay readable on colour e-ink.
- **Alignment**: left (default), justified or centred. Justified lines that
  would need very wide gaps (a long word in a narrow card) stay ragged.
- **Line spacing**: normal (default), relaxed or loose.

The settings are shared: a change on one home screen applies to the other.

## Minutes without a quote

When a minute has no quote, the card shows a line written like one, with the
time in words ("twenty-seven minutes to ten", "a quarter past eleven"),
highlighted like a real quote's time. Two kinds of line take turns: a
narrator for whom nothing happened at that time, and an invitation to the
reader to make the minute theirs.

The lines are in
[`literaryclock.koplugin/core/fallbacks.lua`](literaryclock.koplugin/core/fallbacks.lua):
edit or add lines there without touching the code. The same file sets an
optional attribution line, empty by default.

## Tests

```sh
luajit tests/test_fallbacks.lua
```

Checks the time in words for every minute of the day, and every fallback
line with every form: capital first letter, the time highlighted once,
alternation between the two kinds, no line twice in a row.

## Rebuilding the quotes

The quotes come from the English collection of
[cdmoro/literature-clock](https://github.com/cdmoro/literature-clock).
The build drops only the extreme outliers in length (longer than Q3 + 3 × IQR,
617 characters with the current data: 9 quotes), which would only fit a card
at a tiny font size.
To regenerate the data files:

```sh
python3 tools/build_quotes.py path/to/quotes.en-US.csv literaryclock.koplugin/data/en
```

## Credits

See [NOTICE.md](NOTICE.md) for where the quotes come from and their licence.

## Licence

The code is licensed under the
[GNU Affero General Public License v3.0](LICENSE).
The quotes in `literaryclock.koplugin/data/` are not covered by it: they are
shared under the terms described in [NOTICE.md](NOTICE.md)
(CC BY-NC-SA 2.5).
