#!/usr/bin/env python3
"""Centre nwg-hello's login form, hyprlock-style.

The stock template packs `form-wrapper` into the horizontal `main-box` with
expand=False, fill=False, so the form sits against the left edge. GtkBox
packing has no CSS equivalent, so this writes a replacement template for
nwg-hello.json's "template-name".

The template is derived from the installed template.glade at install time
rather than vendored: ui.py looks up widgets by id, and a stale copy missing
one would crash the greeter. Only form-wrapper's <packing> is changed; the
inner column is already halign=center and vertically centred.

If the expected nodes are missing this exits non-zero and writes nothing, and
install-greeter.sh falls back to the stock layout.

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
