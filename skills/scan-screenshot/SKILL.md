---
name: scan-screenshot
description: "Check a screenshot before sharing: flag PII, secrets and risky content, then fix it by spoofing or redacting."
---

# Scan Screenshot

Screenshot, flag, review, obfuscate. Use before a screenshot goes into a bug report, blog post, README or chat.

## Inputs

- An image path, or a capture mode from the `screenshot` skill.
- Optional: whether the image may go to the model provider. If the user wants it kept local, skip step 3.

## Steps

1. **Capture**, if there is no image yet.
2. **Run the scanner:**
   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/scripts/scan.py" <image> --overlay
   ```
   It prints JSON with numbered `findings` (type, severity, masked text, pixel box), `redact_regions`, and `overlay`, the path of a review image with each finding boxed. `checks` shows which layers ran. Add `--lang eng+heb` for other languages, once the language pack is installed.
3. **Do the vision pass.** Read the original image and look for what patterns cannot see:
   - People's names, faces, avatars, addresses, signatures.
   - Health, financial, legal or workplace details.
   - Notifications, other windows, browser tabs, bookmarks, autofill suggestions.
   - Account names, device names, Wi-Fi names, calendar entries.
   - QR codes, barcodes, text inside images, maps, or a location that can be inferred.
   - Anything the user did not mean to include.

   Continue the numbering from the scanner. Give each item an approximate pixel box, then check the box against the image size.
4. **Report one list** of all findings, by severity: number, type, masked text, and why it matters. Show the overlay path. Never print full secrets in the conversation. Say which layers ran and that the list may be incomplete.
5. **Ask what to hide.** Default to everything critical and high, and let the user drop false alarms. An image with nothing flagged still gets step 7's closing line.
6. **Fix it**, choosing by where the content lives:
   - **Web page still open, mostly text:** `spoof-page-screenshot`, with the flagged text as the map, then recapture. Use `--reveal` on the scanner to get the exact strings. Best looking result.
   - **Anything else:** `redact`, passing the chosen `redact_regions` as `--region` values. Use `--method solid` for secrets; pixelate is fine for names and addresses.
7. **Verify.** Run the scanner on the result and read the image again, confirming each chosen item is gone. Report the clean file's path, what was hidden and how. Warn that the original and the overlay still hold the content, so neither should be shared.

## Data storage

Optional watchlist of the user's own terms, one per line, always flagged as high:

`${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/screenshotting/watchlist.txt`

Offer to add recurring items here, such as family names or medication names. The scanner also reads the `pii-scanner` plugin's `pii-inventory/personal.yaml` when it exists and PyYAML is installed. The file holds real data, so keep it out of repositories.

The overlay is written to `<image_dir>/flagged/<stem>_flagged.png`.

## Notes

- The scanner runs locally and loads no ML models. It takes a few seconds per image.
- OCR misreads and misses text, especially small, stylised or low-contrast text. No findings does not mean safe.
- Names and addresses have no reliable pattern. Without the vision pass, only the watchlist catches them.
- The box for a spoofed finding is irrelevant after recapture: the layout can move, so always rescan.
