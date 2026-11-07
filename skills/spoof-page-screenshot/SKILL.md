---
name: spoof-page-screenshot
description: "Screenshot a web app with fake data: replace real names and private info in the live page with stand-ins, then capture."
---

# Spoof Page Screenshot

Replace private text in a live page with plausible stand-ins, then capture. The result looks like a real app with demo data, with no blur boxes. Changes exist only in the browser tab: a reload restores the page and the app's data is never touched.

## Inputs

- The page: usually a tab the user has open, or a URL.
- What to hide. If the user does not list it, read the page and propose a list.

## Steps

1. **Open the page** with a browser tool that can run JavaScript: Claude in Chrome (`javascript_tool`), a Playwright or Chrome DevTools MCP, or the user's DevTools console as a last resort.
2. **Build the map** of real text to stand-in, and show it to the user before applying it.
   - Read the rendered page and list names, addresses, account labels, IDs and anything else private, including each variant of a term ("Jane Doe", "Jane", "jane.doe").
   - Stand-ins should be the same kind of thing and a similar length, so the layout holds: a made-up drug name for a drug name, not "REDACTED".
   - Keep the map in the conversation. Never write it to a repo or any file that gets shared, because it lists the real values.
3. **Load the script and apply the map.** Read `$CLAUDE_PLUGIN_ROOT/scripts/spoof-dom.js`, run its full text in the page, then run:
   ```js
   __spoof.apply({"Real term": "Stand-in", "Other term": "Other stand-in"})
   ```
   It covers text, common attributes (`title`, `alt`, `aria-label`, `placeholder`), form values, the document title, open shadow roots and same-origin iframes. It keeps watching, so framework re-renders get the same swap. Matching ignores case and respects word boundaries. For partial-word matches, pass `{wholeWord: false}` as the second argument.
4. **Verify the DOM:** `__spoof.verify()`. It matches substrings on purpose, so review each hit:
   - A hit inside an unrelated word ("Ann" in "Annual") is a false alarm.
   - A `rendered text` hit with no matching `text` hit means the term is split across elements: fix that element by hand.
   - Anything counted in `unspoofable` (`img`, `canvas`, `video`, `crossOriginIframe`) can still show private content. Look at each one, then hide it or plan a pixel redaction.
5. **Capture.** Preferred: the browser tool's own viewport screenshot, which leaves out the address bar and tabs (Claude in Chrome: `computer` action `screenshot` with `save_to_disk: true`, then copy the file out of its temp folder). Otherwise use the `screenshot` skill and check the address bar and tab titles for private text.
6. **Check the image itself.** Read the final image and look for every term in the map, plus anything private that was not listed. A clean DOM does not prove a clean picture: chart labels and text inside images do not appear in it. If the page stays private, use `ocr-screenshot` with a local engine and search its output for the terms as well.
7. **Clean up:** reload the tab, or leave it for the user if they want to look. Report the output path.

## Notes

- Never save or submit anything while the spoof is active. Stand-in values in form fields would be written to the app as real data.
- `apply` refuses a stand-in that contains an original, because the swap would repeat on every re-render.
- Closed shadow roots and cross-origin iframes cannot be reached. `verify` cannot see into them either, so step 6 is the only check there.
- Numbers, dates and times are only swapped if listed. Check whether they identify anyone.
- For a whole screen of private data in an app you control, seeding demo data may be simpler.
- `tests/spoof-fixture.html` is a test page with invented data. Serve the repo root locally and open it to try the script.
