import os
import json
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path
import tomllib
import time
import re

WIKIJS_URL = os.environ.get("WIKIJS_URL", "").rstrip("/")
WIKIJS_GRAPHQL_URL = f"{WIKIJS_URL}/graphql"
WIKIJS_API_TOKEN = os.environ.get("WIKIJS_API_TOKEN", "")
WIKI_PAGE_PATH = "seasons/season4/mods"
WIKI_PAGE_TITLE = "Season 4 Mods"
MODS_DIR = Path.cwd() / "mods"

CACHE_DIR = Path.cwd() / ".cache" / "modrinth"
IS_CI = os.environ.get("CI", "").lower() in ("true", "1")
DISABLE_CACHE = os.environ.get("DISABLE_CACHE", "").lower() in ("true", "1") or IS_CI
CACHE_EXPIRY_SECONDS = 0 if DISABLE_CACHE else (86400 * 7)

class GraphQLClient:
    def __init__(self, url, token=None):
        self.url = url
        self.headers = {
            "Content-Type": "application/json",
            "User-Agent": "CloverCraft/1.0.0"
        }
        if token:
            self.headers["Authorization"] = f"Bearer {token}"

    def execute(self, query: str, variables: dict = None):
        payload = json.dumps({"query": query, "variables": variables or {}}).encode("utf-8")
        req = urllib.request.Request(self.url, data=payload, headers=self.headers, method="POST")
        
        try:
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read().decode())
        except urllib.error.HTTPError as e:
            print(f"HTTP Error {e.code}: {e.read().decode()}")
            return None
        except Exception as e:
            print(f"Network Error: {e}")
            return None


GET_PAGE_QUERY = """
query GetPageByPath($path: String!) {
  pages {
    search(query: $path) {
      results {
        id
        path
      }
    }
  }
}
"""

GET_ALL_PAGES_QUERY = """
query ListModPages {
  pages {
    list(orderBy: TITLE) {
      id
      path
      title
    }
  }
}
"""

UPDATE_MUTATION = """
mutation UpdatePage($id: Int!, $content: String!, $description: String!, $title: String!) {
  pages {
    update(
      id: $id
      content: $content
      description: $description
      editor: "markdown"
      isPublished: true
      isPrivate: false
      locale: "en"
      tags: ["modpack"]
      title: $title
      scriptCss: "table thead { display: none !important; }"
    ) {
      responseResult {
        succeeded
        message
      }
    }
  }
}
"""

CREATE_MUTATION = """
mutation CreatePage($content: String!, $description: String!, $path: String!, $title: String!) {
  pages {
    create(
      content: $content
      description: $description
      editor: "markdown"
      isPublished: true
      isPrivate: false
      locale: "en"
      path: $path
      tags: ["modpack"]
      title: $title
      scriptCss: "table thead { display: none !important; }"
    ) {
      responseResult {
        succeeded
        message
      }
    }
  }
}
"""

def fetch_existing_wiki_pages(client):
    if not client or not WIKIJS_API_TOKEN:
        return {}
    res = client.execute(GET_ALL_PAGES_QUERY)
    existing = {}
    if res and "data" in res and "pages" in res["data"]:
        for page in res["data"]["pages"].get("list", []):
            path = page.get("path", "")
            existing[path.lower()] = path
    return existing

def fetch_modrinth_details(project_id):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_file = CACHE_DIR / f"{project_id}.json"

    if cache_file.exists() and CACHE_EXPIRY_SECONDS > 0:
        file_age = time.time() - cache_file.stat().st_mtime
        if file_age < CACHE_EXPIRY_SECONDS:
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass

    url = f"https://api.modrinth.com/v2/project/{project_id}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "CloverCraft/1.0.0"}
    )

    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump(data, f)
                return data
    except Exception as e:
        print(f"Failed to fetch Modrinth data for {project_id}: {e}")

        if cache_file.exists():
            print(f"Using stale cache for {project_id} to prevent workflow failure.")
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
    return None


def parse_packwiz_mods():
    mods_list = []
    
    if not MODS_DIR.exists():
        print(f"Directory {MODS_DIR} not found.")
        return mods_list

    client_count = 0
    server_count = 0
    shared_count = 0

    for file_path in MODS_DIR.glob("*.pw.toml"):
        with open(file_path, "rb") as f:
            parsed = tomllib.load(f)

        side = parsed.get("side", "both").lower()
        if side == "client":
            client_count += 1
        elif side == "server":
            server_count += 1
        else:
            shared_count += 1

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
            "additional_categories": [],
            "downloads": None,
            "source": None,
            "issues": None,
            "wiki": None,
            "discord": None,
            "game_versions": [],
            "environment": [],
            "loaders": [],
        }

        print("Attempting to fetch {} ({})".format(modrinth_mod_id, mod_data["name"]))

        if modrinth_mod_id:
            data = fetch_modrinth_details(modrinth_mod_id)
            if data:
                print("Fetched {} ({})!".format(modrinth_mod_id, data.get("title", mod_data["name"])))
                mod_data["name"] = data.get("title", mod_data["name"])
                mod_data["description"] = data.get("description", mod_data["description"])
                mod_data["icon"] = data.get("icon_url") or mod_data["icon"]
                mod_data["link"] = f"https://modrinth.com/mod/{data.get('slug', modrinth_mod_id)}/version/{modrinth_mod_version}"
                mod_data["categories"] = data.get("categories", [])
                mod_data["additional_categories"] = data.get("additional_categories", [])
                mod_data["downloads"] = data.get("downloads")
                mod_data["source"] = data.get("source_url")
                mod_data["issues"] = data.get("issues_url")
                mod_data["wiki"] = data.get("wiki_url")
                mod_data["discord"] = data.get("discord_url")
                mod_data["game_versions"] = data.get("game_versions", [])

                # Allowed values: client_and_server client_only client_only_server_optional singleplayer_only server_only server_only_client_optional dedicated_server_only client_or_server client_or_server_prefers_both unknown 
                mod_data["environment"] = data.get("environment", [])
                mod_data["loaders"] = data.get("loaders", [])

        mods_list.append(mod_data)

    print("Fetched a total of {} mods ({} Client, {} Server, {} Shared).".format(len(mods_list), client_count, server_count, shared_count))

    return sorted(mods_list, key=lambda x: x["name"].lower())

def slugify(text):
    slug = text.lower().replace("|", "").replace("/", "-").replace(" ", "-")
    slug = re.sub(r'[^a-z0-9\-]', '', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')

def format_side(side_str):
    s = str(side_str).lower()
    if s == "client":
        return "Client"
    elif s == "server":
        return "Server"
    return "Both"

def format_environment(env_list):
    if not env_list:
        return None
    env_map = {
        "client_and_server": "Client & Server",
        "client_only": "Client Only",
        "client_only_server_optional": "Client Only (Server Optional)",
        "singleplayer_only": "Singleplayer Only",
        "server_only": "Server Only",
        "server_only_client_optional": "Server Only (Client Optional)",
        "dedicated_server_only": "Dedicated Server Only",
        "client_or_server": "Client or Server",
        "client_or_server_prefers_both": "Client or Server (Prefers Both)"
    }
    return ", ".join([env_map.get(e, e.replace("_", " ").title()) for e in env_list])

def escape_markdown_table_cell(text):
    if not text:
        return ""
    return str(text).replace("|", "&#124;")

def generate_wikijs_markdown(mods, existing_wiki_pages=None):
    if existing_wiki_pages is None:
        existing_wiki_pages = {}

    categorized_mods = {}
    for mod in mods:
        categories = mod.get("categories", [])
        primary_cat = categories[0].replace("-", " ").title() if categories else "Uncategorized"
        categorized_mods.setdefault(primary_cat, []).append(mod)

    sorted_categories = sorted(categorized_mods.keys())

    markdown = [
        '<style>',
        'table thead { display: none !important; }',
        '</style>',
        '<center>',
        '  <span style="font-size:30px;">CloverCraft Mods List</span>',
        '</center>',
        '',
        '> Mods are separated by client side, server side or both - you\'ll want to keep this in mind when doing anything with pack testing in singleplayer. For more info about how the CloverCraft\'s Modpack works see [here](https://github.com/CloverCraftSMP/Season4).',
        '{.is-info}',
        '',
        '---',
        '',
        '# Table of Content {.tabset}',
        ''
    ]

    GRID_COLUMNS = 4

    for category in sorted_categories:
        cat_mods = categorized_mods[category]
        markdown.append(f'<div style="font-size:15px;">\n')
        markdown.append(f'## {category}')
        markdown.append('</div>\n')

        markdown.append(f'*Total of {len(cat_mods)} {category.lower()} mods.*')

        markdown.append('| ' + ' | '.join([' '] * GRID_COLUMNS) + ' |')
        markdown.append('| ' + ' | '.join(['---'] * GRID_COLUMNS) + ' |')

        for i in range(0, len(cat_mods), GRID_COLUMNS):
            row_mods = cat_mods[i:i + GRID_COLUMNS]
            row_cells = []
            for mod in row_mods:
                mod_anchor = slugify(mod["name"])
                icon_url = mod.get("icon") or "https://cdn.modrinth.com/assets/unknown_server.png"
                safe_name = escape_markdown_table_cell(mod["name"])

                cell_content = (
                    f'<a href="#{mod_anchor}" style="display:flex; align-items:center; gap:8px; text-decoration:none;">'
                    f'<img src="{icon_url}" width="24" height="24" style="border-radius:4px; object-fit:contain; flex-shrink:0;" />'
                    f'<span>{safe_name}</span>'
                    f'</a>'
                )

                row_cells.append(cell_content)
            
            while len(row_cells) < GRID_COLUMNS:
                row_cells.append(' ')

            markdown.append('| ' + ' | '.join(row_cells) + ' |')

        # for mod in cat_mods:
        #     mod_anchor = slugify(mod["name"])
        #     markdown.append(f'- [{mod["name"]}](#{mod_anchor})')

    markdown.append('---')
    markdown.append('')
    markdown.append('# Mods {.tabset}')
    markdown.append('')

    for category in sorted_categories:
        cat_mods = categorized_mods[category]
        markdown.append(f'## {category} {"{.tabset}"}')

        for mod in cat_mods:
            mod_slug = slugify(mod["name"])
            icon_url = mod.get("icon") or "https://cdn.modrinth.com/assets/unknown_server.png"
            
            markdown.append(f'### <img src="{icon_url}" width="32" height="32" style="vertical-align:middle; margin-right:8px; border-radius:6px; object-fit:contain;" /> {mod["name"]}')

            side_text = format_side(mod.get("side", "both"))
            env_formatted = format_environment(mod.get("environment")) or "N/A"
            loaders_str = ", ".join([l.title() for l in mod["loaders"]]) if mod.get("loaders") else "N/A"

            if mod.get("game_versions"):
                versions = mod["game_versions"]
                if len(versions) > 3:
                    version_display = f"{versions[0]} - {versions[-1]} ({len(versions)} versions)"
                else:
                    version_display = ", ".join(versions)
            else:
                version_display = "N/A"

            markdown.append(f'{mod["description"]}\n')

            expected_wiki_path = f"seasons/season4/mods/{mod_slug}"
            has_wiki_page = expected_wiki_path.lower() in existing_wiki_pages

            if has_wiki_page:
                wiki_indicator = f"[View Dedicated Wiki Page](/{expected_wiki_path})"
            else:
                wiki_indicator = "*No dedicated wiki page available*"

            markdown.append('| Property | Value |')
            markdown.append('| --- | --- |')
            markdown.append(f'| **Side** | {side_text} |')
            markdown.append(f'| **Environment** | {env_formatted} |')
            markdown.append(f'| **Loaders** | {loaders_str} |')
            markdown.append(f'| **Game Versions** | {version_display} |')
            markdown.append(f'| **Local Documentation** | {wiki_indicator} |')

            markdown.append('')
            markdown.append('')

            links = []
            if mod.get("link") and mod["link"] != "#":
                links.append(f"[Modrinth]({mod['link']})")
            if mod.get("source"):
                links.append(f"[GitHub]({mod['source']})")
            if mod.get("issues"):
                links.append(f"[Issues]({mod['issues']})")
            if mod.get("wiki"):
                links.append(f"[Wiki]({mod['wiki']})")
            if mod.get("discord"):
                links.append(f"[Discord]({mod['discord']})")

            links_str = " | ".join(links) if links else "No external links available"
            markdown.append(f'**Links:** {links_str}')

            markdown.append(f'> [Jump back to Table of Contents](#table-of-content)')
            markdown.append('{.is-info}')
            markdown.append('')
            markdown.append('<br>')
            markdown.append('')

    return "\n".join(markdown)


def update_wiki_page(content):
    client = GraphQLClient(WIKIJS_GRAPHQL_URL, token=WIKIJS_API_TOKEN)

    search_res = client.execute(GET_PAGE_QUERY, {"path": WIKI_PAGE_PATH})
    page_id = None

    if search_res and "data" in search_res:
        results = search_res["data"].get("pages", {}).get("search", {}).get("results", [])
        for item in results:
            if item.get("path") == WIKI_PAGE_PATH:
                page_id = item.get("id")
                break
    
    if page_id:
        print(f"Found existing Wiki.js page (ID: {page_id}). Updating...")
        res = client.execute(UPDATE_MUTATION, {
            "id": int(page_id),
            "content": content,
            "description": "List of mods",
            "title": WIKI_PAGE_TITLE
        })
        action = "update"
    else:
        print(f"Page not found at '{WIKI_PAGE_PATH}'. Creating new page...")
        res = client.execute(CREATE_MUTATION, {
            "content": content,
            "description": "List of mods",
            "path": WIKI_PAGE_PATH,
            "title": WIKI_PAGE_TITLE
        })
        action = "create"

    if res and "data" in res:
        result_data = res["data"].get("pages", {}).get(action, {}).get("responseResult", {})
        if result_data.get("succeeded"):
            print("Wiki.js page synchronized successfully!")
        else:
            print("Wiki.js sync failed:", result_data.get("message"))
    elif res and "errors" in res:
        print("GraphQL Error:", json.dumps(res["errors"], indent=2))

if __name__ == "__main__":
    print("Parsing Packwiz TOML files...")
    mods = parse_packwiz_mods()
    print(f"Found {len(mods)} mods.")

    client = GraphQLClient(WIKIJS_GRAPHQL_URL, token=WIKIJS_API_TOKEN) if WIKIJS_API_TOKEN else None
    existing_pages = fetch_existing_wiki_pages(client) if client else {}

    print("Generating Markdown content...")
    md_content = generate_wikijs_markdown(mods, existing_wiki_pages=existing_pages)
    
    if WIKIJS_API_TOKEN:
        print("Updating Wiki.js...")
        update_wiki_page(md_content)
        print("Done!")
    else:
        with open("preview.md", "w", encoding="utf-8") as f:
            f.write(md_content)
        print("No WIKIJS_API_TOKEN found. Output saved locally to preview.md")