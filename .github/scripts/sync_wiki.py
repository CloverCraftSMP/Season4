import os
import json
import urllib.request
import urllib.parse
from pathlib import Path
import tomllib

WIKIJS_URL = os.environ.get("WIKIJS_URL", "").rstrip("/")
WIKIJS_GRAPHQL_URL = f"{WIKIJS_URL}/graphql"
WIKIJS_API_TOKEN = os.environ.get("WIKIJS_API_TOKEN", "")
WIKI_PAGE_PATH = "test/mods"
WIKI_PAGE_TITLE = "Mods"
MODS_DIR = Path.cwd() / "mods"


def fetch_modrinth_details(project_id):
    url = f"https://api.modrinth.com/v2/project/{project_id}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "CloverCraft/1.0.0"}
    )
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                return json.loads(response.read().decode())
    except Exception as e:
        print(f"Failed to fetch Modrinth data for {project_id}: {e}")
    return None


def parse_packwiz_mods():
    mods_list = []
    
    if not MODS_DIR.exists():
        print(f"Directory {MODS_DIR} not found.")
        return mods_list

    for file_path in MODS_DIR.glob("*.pw.toml"):
        with open(file_path, "rb") as f:
            parsed = tomllib.load(f)

        side = parsed.get("side", "both").lower()

        update_info = parsed.get("update", {})
        mod_info = update_info.get("modrinth", {})

        modrinth_mod_id = mod_info.get("mod-id")
        modrinth_mod_version = mod_info.get("version")

        mod_data = {
            "name": parsed.get("name", file_path.stem),
            "side": side,
            "description": "No description provided.",
            "icon": "https://cdn.modrinth.com/assets/unknown_server.png",
            "link": "#",
            "categories": [],
            "downloads": None
        }

        if modrinth_mod_id:
            data = fetch_modrinth_details(modrinth_mod_id)
            if data:
                mod_data["name"] = data.get("title", mod_data["name"])
                mod_data["description"] = data.get("description", mod_data["description"])
                mod_data["icon"] = data.get("icon_url") or mod_data["icon"]
                mod_data["link"] = f"https://modrinth.com/mod/{data.get('slug', modrinth_mod_id)}/version/{modrinth_mod_version}"
                mod_data["categories"] = data.get("categories", [])
                mod_data["downloads"] = data.get("downloads")

        mods_list.append(mod_data)

    return sorted(mods_list, key=lambda x: x["name"].lower())


def generate_html_cards(mods):
    card_elements = []

    for mod in mods:
        side = mod["side"]
        if side == "client":
            side_label, side_class = "Client", "side-client"
        elif side == "server":
            side_label, side_class = "Server", "side-server"
        else:
            side_label, side_class = "Both", "side-both"

        side_badge = f'<span class="mod-side-badge {side_class}">{side_label}</span>'

        categories_html = "".join([
            f'<span class="mod-tag">{cat}</span>' for cat in mod["categories"]
        ])

        downloads_html = (
            f'<span class="mod-downloads">{mod["downloads"]:,} DLs</span>'
            if mod["downloads"] is not None else ""
        )

        card_html = f"""
        <div class="mod-card">
          <div class="mod-card-header">
            <img src="{mod['icon']}" alt="{mod['name']} Icon" class="mod-icon" loading="lazy" />
            <div class="mod-title-area">
              <div class="mod-title-row">
                <h3 class="mod-title">{mod['name']}</h3>
                {side_badge}
              </div>
              {downloads_html}
            </div>
          </div>
          <p class="mod-description">{mod['description']}</p>
          <div class="mod-card-footer">
            <div class="mod-tags">{categories_html}</div>
            <a href="{mod['link']}" target="_blank" rel="noopener noreferrer" class="mod-button">
              View on Modrinth
            </a>
          </div>
        </div>
        """
        card_elements.append(card_html)

    cards_joined = "\n".join(card_elements)

    return f"""
<style>
  .mod-grid {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 1.25rem;
    margin-top: 1.5rem;
  }}
  .mod-card {{
    background-color: var(--v-background-base, #1e1e24);
    border: 1px solid var(--v-border-base, rgba(255, 255, 255, 0.1));
    border-radius: 12px;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
    box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  }}
  .mod-card:hover {{
    transform: translateY(-4px);
    box-shadow: 0 8px 16px rgba(0,0,0,0.2);
    border-color: #1bd96a;
  }}
  .mod-card-header {{ display: flex; align-items: flex-start; gap: 0.85rem; margin-bottom: 0.75rem; }}
  .mod-icon {{ width: 48px; height: 48px; border-radius: 8px; object-fit: cover; flex-shrink: 0; }}
  .mod-title-area {{ display: flex; flex-direction: column; flex-grow: 1; }}
  .mod-title-row {{ display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }}
  .mod-title {{ margin: 0 !important; font-size: 1.05rem !important; font-weight: 600; line-height: 1.2; }}
  .mod-side-badge {{ font-size: 0.65rem; font-weight: 700; text-transform: uppercase; padding: 2px 6px; border-radius: 4px; letter-spacing: 0.5px; flex-shrink: 0; }}
  .side-both {{ background-color: rgba(59, 130, 246, 0.2); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3); }}
  .side-client {{ background-color: rgba(168, 85, 247, 0.2); color: #c084fc; border: 1px solid rgba(168, 85, 247, 0.3); }}
  .side-server {{ background-color: rgba(249, 115, 22, 0.2); color: #fb923c; border: 1px solid rgba(249, 115, 22, 0.3); }}
  .mod-downloads {{ font-size: 0.75rem; opacity: 0.7; margin-top: 0.25rem; }}
  .mod-description {{ font-size: 0.88rem; opacity: 0.85; line-height: 1.4; margin-bottom: 1rem; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }}
  .mod-card-footer {{ display: flex; flex-direction: column; gap: 0.75rem; }}
  .mod-tags {{ display: flex; flex-wrap: wrap; gap: 0.35rem; min-height: 24px; }}
  .mod-tag {{ font-size: 0.7rem; padding: 2px 8px; border-radius: 12px; background: rgba(255, 255, 255, 0.08); text-transform: capitalize; opacity: 0.8; }}
  .mod-button {{ display: inline-block; text-align: center; background-color: #1bd96a; color: #0d0d0d !important; font-weight: 600; font-size: 0.85rem; padding: 0.5rem 1rem; border-radius: 6px; text-decoration: none !important; transition: background-color 0.2s ease; }}
  .mod-button:hover {{ background-color: #15b054; }}
</style>

<h1>{WIKI_PAGE_TITLE}</h1>
<p><em>Auto-generated list of {len(mods)} mods.</em></p>

<div class="mod-grid">
  {cards_joined}
</div>
"""


def update_wiki_page(content):
    mutation = """
    mutation ($content: String!, $description: String!, $path: String!, $title: String!) {
      pages {
        create(
          content: $content
          description: $description
          editor: "html"
          isPublished: true
          isPrivate: false
          locale: "en"
          path: $path
          tags: ["modpack"]
          title: $title
        ) {
          responseResult {
            succeeded
            message
          }
        }
      }
    }
    """

    payload = json.dumps({
        "query": mutation,
        "variables": {
            "content": content,
            "description": "Card view of mods",
            "path": WIKI_PAGE_PATH,
            "title": WIKI_PAGE_TITLE
        }
    }).encode("utf-8")

    req = urllib.request.Request(
        WIKIJS_GRAPHQL_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {WIKIJS_API_TOKEN}"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode())
            print("Wiki.js Response:", json.dumps(result, indent=2))
    except Exception as e:
        print("Failed to update Wiki.js:", e)


if __name__ == "__main__":
    print("Parsing Packwiz TOML files...")
    mods = parse_packwiz_mods()
    print(f"Found {len(mods)} mods. Generating HTML Cards...")
    html_content = generate_html_cards(mods)
    
    if WIKIJS_API_TOKEN:
        print("Updating Wiki.js...")
        update_wiki_page(html_content)
        print("Done!")
    else:
        with open("preview.html", "w", encoding="utf-8") as f:
            f.write(html_content)
        print("No WIKIJS_API_TOKEN found. Output saved locally to preview.html")