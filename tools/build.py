#!/usr/bin/env python3
"""Build WantedUnbound.rbxlx (open directly in Roblox Studio) and sourcemap.json
from the src/ folder, without needing Rojo installed.

Usage: python3 tools/build.py
"""
import json
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (service, container folder name, source dir)
MAPPING = [
    ("ReplicatedStorage", None, "Shared", "src/shared"),
    ("ServerScriptService", None, "Server", "src/server"),
    ("StarterPlayer", "StarterPlayerScripts", "Client", "src/client"),
]


def script_class(filename):
    if filename.endswith(".server.lua"):
        return "Script", filename[: -len(".server.lua")]
    if filename.endswith(".client.lua"):
        return "LocalScript", filename[: -len(".client.lua")]
    return "ModuleScript", filename[: -len(".lua")]


def list_scripts(rel_dir):
    out = []
    for name in sorted(os.listdir(os.path.join(ROOT, rel_dir))):
        if name.endswith(".lua"):
            cls, inst_name = script_class(name)
            out.append((cls, inst_name, f"{rel_dir}/{name}"))
    return out


_ref_counter = [0]


def ref():
    _ref_counter[0] += 1
    return "RBX%032X" % _ref_counter[0]


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children="", source=None, extra_props=""):
    props = f'<string name="Name">{escape(name)}</string>' + extra_props
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{props}</Properties>{children}</Item>'


def build_rbxlx():
    services = {}
    for service, sub, folder, rel in MAPPING:
        scripts = ""
        for cls, name, path in list_scripts(rel):
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                scripts += item(cls, name, source=f.read())
        folder_xml = item("Folder", folder, scripts)
        if sub:
            folder_xml = item(sub, sub, folder_xml)
        services.setdefault(service, []).append(folder_xml)

    # StreamingEnabled off: the minimap and police AI expect the whole city to be loaded.
    workspace_props = '<bool name="StreamingEnabled">false</bool>'
    lighting_props = '<token name="Technology">4</token>'  # Future lighting for the neon look
    body = item("Workspace", "Workspace", extra_props=workspace_props)
    body += item("Lighting", "Lighting", extra_props=lighting_props)
    for service, kids in services.items():
        body += item(service, service, "".join(kids))
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        + body
        + "</roblox>"
    )
    out = os.path.join(ROOT, "WantedUnbound.rbxlx")
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    print("wrote", out)


def build_sourcemap():
    children = {}
    for service, sub, folder, rel in MAPPING:
        scripts = [
            {"name": name, "className": cls, "filePaths": [path]}
            for cls, name, path in list_scripts(rel)
        ]
        node = {"name": folder, "className": "Folder", "filePaths": [rel], "children": scripts}
        if sub:
            node = {"name": sub, "className": sub, "children": [node]}
        children.setdefault(service, []).append(node)
    tree = {
        "name": "WantedUnbound",
        "className": "DataModel",
        "filePaths": ["default.project.json"],
        "children": [
            {"name": s, "className": s, "children": kids} for s, kids in children.items()
        ],
    }
    out = os.path.join(ROOT, "sourcemap.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(tree, f, indent=1)
    print("wrote", out)


if __name__ == "__main__":
    build_sourcemap()
    build_rbxlx()
