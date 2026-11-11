# xkb — Norwegian with a symbol layer

Stows `~/.config/xkb/symbols/nosym`, a custom XKB layout that libxkbcommon picks
up from `~/.config/xkb`. Hyprland selects it in `hypr/.config/hypr/general.lua`:

```lua
kb_layout  = "nosym",
kb_options = "lv5:lsgt_switch",
```

The normal Norwegian layout is unchanged — plain, Shift, AltGr and Shift+AltGr
all type what they always did. Holding the **`< >` key** (left of Z) adds a
symbol layer on the letter keys, so the brackets and dead-key symbols are
reachable from the home row.

## Map (hold `< >`)

```
        q   w   e   r   t     y   u   i   o   p   å
top:    `   ~   ^   |   %     &   \   /   *   @   $

        a   s   d   f   g     h   j   k   l   ø   æ
home:   <   [   (   {   =     #   }   )   ]   >   ;

        z   x   c   v   b     n   m   ,   .
bottom: !   "   '   +   _     ?   :   €   …
```

- **Brackets are mirrored pairs** — opening on the left hand, closing on the
  same finger of the right hand: `{ }` index, `( )` middle, `[ ]` ring,
  `< >` pinky.
- **`=` sits on G**, between the brackets.
- **`` ` ~ ^ `` are plain characters** here, not dead keys — no space needed.
- Shift doesn't change the layer: Shift+`< >`+key types the same symbol.

The `< >` key itself no longer types `<` or `>`; they're on A and Ø in the layer.
This needs an ISO board (one with a key between left Shift and Z).

## Changing it

- **Move the layer key:** change `kb_options` in `general.lua`, e.g.
  `lv5:ralt_switch`, `lv5:rctrl_switch` or `lv5:caps_switch`
  (`grep lv5: /usr/share/X11/xkb/rules/evdev.lst` lists them all).
- **Change a symbol:** edit level 5 and 6 (the last two entries) of the key in
  `symbols/nosym`. Key names: `AD01`–`AD11` top row, `AC01`–`AC11` home row,
  `AB01`–`AB10` bottom row. Keysym names are in
  `/usr/include/xkbcommon/xkbcommon-keysyms.h` (without `XKB_KEY_`).
- **Check it compiles** before reloading:

  ```bash
  xkbcli compile-keymap --include ~/.config/xkb --include-defaults \
      --layout nosym --options lv5:lsgt_switch >/dev/null
  ```

- **Apply:** `hyprctl reload`. If the keyboard comes up as US, the file failed
  to compile — run the check above.
