#!/usr/bin/env python3
"""Centre nwg-hello's login form, hyprlock-style.

nwg-hello inherits the Sugar Candy SDDM layout: `main-box` is a horizontal
GtkBox, and the stock template packs `form-wrapper` into it with
expand=False, fill=False. So form-wrapper only ever gets its natural width and
sits in a column against the left edge, with the wallpaper filling the rest.
hyprlock centres its clock, date and input field, so to match it the form has
to move to the middle.

This cannot be done in CSS: GtkBox distributes space using GtkBuilder
<packing> properties, and those have no CSS equivalent. nwg-hello's supported
escape hatch is `"template-name"` in nwg-hello.json, which points at a
replacement .glade in /etc/nwg-hello/.

The obvious way to use that hook is to vendor an edited copy of
template.glade into the repo. This script exists instead because vendoring is
a bad trade here: ui.py calls builder.get_object("lbl-clock") and friends on
whatever template it is handed, so a stale copy missing a widget added by a
later nwg-hello returns None and the greeter dies on startup -- and a greeter
that dies on startup means being unable to log in. Deriving the template from
the installed one at install time keeps it in step with whatever version apt
put on disk, and the one edit below is all this repo actually owns.

If the expected nodes are not found this exits non-zero and writes nothing;
install-greeter.sh then leaves "template-name" empty and the greeter falls
back to the stock left-aligned layout. Ugly beats unbootable.

Only the <packing> is touched, and that is deliberate -- it is the whole fix.
Two things that look like they should also be needed are not:

  - halign/hexpand on form-wrapper: unnecessary, and they do not even apply.
    Measured at runtime, form-wrapper reports halign=fill with these set. The
    inner width-request=400 column already carries halign=center, so once
    form-wrapper is given the full width the column centres itself.
  - valign on anything: the form is already vertically centred. Measured, the
    inner box lands at y=304 h=831 on a 1440px screen -- 304px of slack above
    and 305 below. It only reads as top-heavy because the clock carries the
    visual weight.

Usage: greeter-template.py <input.glade> <output.glade>
"""

import sys
import xml.etree.ElementTree as ET


def find_child_wrapper(root, obj_id):
    """Return the <child> element wrapping the object with this id.

    The <packing> block lives on the <child>, not on the <object> -- that is
    the element GtkBox reads when handing out space.
    """
    for parent in root.iter():
        for child in parent.findall("child"):
            obj = child.find("object")
            if obj is not None and obj.get("id") == obj_id:
                return child
    return None


def set_packing(child, name, value):
    packing = child.find("packing")
    if packing is None:
        packing = ET.SubElement(child, "packing")
    for prop in packing.findall("property"):
        if prop.get("name") == name:
            prop.text = value
            return
    prop = ET.SubElement(packing, "property")
    prop.set("name", name)
    prop.text = value


def main():
    if len(sys.argv) != 3:
        print("usage: greeter-template.py <input.glade> <output.glade>", file=sys.stderr)
        return 2

    src, dst = sys.argv[1], sys.argv[2]
    tree = ET.parse(src)
    root = tree.getroot()

    child = find_child_wrapper(root, "form-wrapper")
    if child is None:
        print("greeter-template: no 'form-wrapper' <child> in template", file=sys.stderr)
        return 1

    # Hand form-wrapper the full width of main-box. The inner column's
    # existing halign=center then does the actual centring.
    set_packing(child, "expand", "True")
    set_packing(child, "fill", "True")

    tree.write(dst, encoding="UTF-8", xml_declaration=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
