# 🏷️ LrAutoKeyword — AI keywording for Lightroom Classic

**A Lightroom Classic plugin that tags your photos with Claude AI — using *your own* keyword list, never inventing new ones.**

Select photos, run *Auto-Tag*, review, apply. The plugin exports small JPEG previews, asks [Claude](https://www.anthropic.com/claude) which of **your catalog's keywords** fit each photo (split into *certain* and *probable*), and shows you a validation dialog before anything is written to the catalog.

## Why it's different

Most AI taggers invent arbitrary keywords and flood your catalog. LrAutoKeyword only ever picks from the keyword list you already curated — your taxonomy stays yours. A glossary file lets you explain your cryptic keywords to the AI (see `tag_descriptions_example.lua`).

## Features

- **Your keywords only** — Claude chooses from the catalog's keyword list, split into "certain" and "probable".
- **Review before apply** — a dialog shows every suggestion per photo; nothing is written without your OK.
- **Keyword glossary** — describe non-obvious keywords (`urbex`, `frame`…) in `tag_descriptions.lua` so the AI uses them correctly.
- **Configurable** — model (Claude Sonnet by default), preview size, batch size, API key, all in the settings dialog.
- Optional **AutoHotkey script** for one-key tagging from inside Lightroom.

## Installation

1. Download/clone this repository.
2. Lightroom Classic → *File > Plug-in Manager > Add* → select `LrAutoKeyword.lrplugin`.
3. Open *Library > Plug-in Extras > Parametres du plugin* and paste your [Anthropic API key](https://console.anthropic.com/).
4. Select photos → *Library > Plug-in Extras > Auto-Tag avec Claude*.

Optional: copy `tag_descriptions_example.lua` to `tag_descriptions.lua` (ignored by git) and describe your own keywords.

## Privacy & cost

- Selected photos are exported as **small JPEG previews and sent to the Anthropic API** for analysis. Don't use it on photos you're not comfortable sending to a cloud API.
- API usage is **billed by Anthropic to your key** (typically well under a cent per photo with the default settings).
- The API key is stored in Lightroom's plugin preferences, never in this repository.

## Notes

- UI is currently in French; contributions welcome.
- `json.lua` is based on work by Jeffrey Friedl (CC-BY 3.0) — see the file header.
- Lightroom is a trademark of Adobe Inc.; this is an unofficial third-party plugin.

## Support

If LrAutoKeyword saved you hours of keywording:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/hypedigger)

## License

[MIT](LICENSE) (except `json.lua`, CC-BY 3.0 as noted above).
