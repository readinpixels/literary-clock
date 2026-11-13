# Literary Clock for KOReader

A KOReader plugin that tells the time with a line from a book that mentions
it, as a module for the home screens of
[Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin) and
[SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin).

> At **six minutes past midnight**, death relieved the sufferer.
>
> *West of Hell's Fringe*, Glenn Shirley

> **Work in progress.** Not tested on a device yet.

## How it works

- Every minute the card shows a quote for that minute, with the time in bold
  and the title and author underneath.
- When a minute has several quotes, it picks one that is readable in the
  card, and the choice changes from day to day.
- The quote fills the card at the largest font size that fits.
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
  marks as not safe for work. With it on, 29 minutes of the day have no quote
  (see below).
- **Show title and author**.

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
To regenerate the data files:

```sh
python3 tools/build_quotes.py path/to/quotes.en-US.csv literaryclock.koplugin/data/en
```

## Credits

See [NOTICE.md](NOTICE.md) for where the quotes come from and their licence.
