# A4 Page Layout in Blank Document Editor

This document explains how the A4 page layout is implemented in the **Blank Document Editor** and what each part of the page contains.

## Overview

The editor renders each page as a fixed‑size **A4 canvas** with:

- **Header** at the top (branding, title, optional logo)
- **Body** in the middle (editable content sections)
- **Footer** at the bottom (branding, page information, optional logo)

The main implementation lives in:

- `frontend_flutter/lib/pages/creator/blank_document_editor_page.dart`
- `frontend_flutter/lib/widgets/header.dart`

## Page Size

In `BlankDocumentEditorPage._buildA4Pages()` each page is rendered as:

- `pageWidth = 900` logical pixels
- `pageHeight = 1273` logical pixels

These values maintain the A4 aspect ratio (210mm × 297mm ≈ 0.707) while giving enough on‑screen size for editing.

All sections are rendered inside a `Container` with these fixed dimensions, so:

- Each section corresponds to **one A4 page**.
- The visual layout is stable and suitable for future PDF export.

## Header

The header for each A4 page uses the shared `DocumentHeader` widget:

- File: `frontend_flutter/lib/widgets/header.dart`
- Class: `DocumentHeader`

Key properties:

- `title` – optional document title. If `null` or empty, no title text is shown.
- `subtitle` – optional secondary text (typically the section title).
- `leading` – optional widget on the left (typically a logo).
- `trailing` – optional widget on the right.
- `onTap` – optional callback; when provided, the entire header area is clickable.

In the blank document editor, the header is configured in `_buildA4Pages()`:

- `title` is taken from `_titleController`.
- `subtitle` is the current section title.
- If `_headerLogoUrl` is set, `leading` is an `Image.network` built from that URL.
- `onTap` is wired to `_pickHeaderLogo()`, which opens the content library and lets the user choose an image.

Behavior:

- Clicking the header opens the **Content Library** dialog.
- When the user selects an image item, `_handleImageForBranding()` can set it as the **header logo**.
- The same header (title + logo) appears on **every A4 page**.

## Body

The body is the editable area between header and footer. For each page:

- The body is wrapped in an `Expanded` + `SingleChildScrollView`.
- Actual content is built by `_buildSectionContent(index)`.
- Each section corresponds to a `DocumentSection` model:
  - Title and main text (via text controllers and focus nodes)
  - Optional background color / background image
  - Inline images and tables

The body is where:

- Users type text.
- Content from the **Content Library** is inserted.
- Background images can be applied per page.

## Footer

The footer for each A4 page uses the shared `DocumentFooter` widget:

- File: `frontend_flutter/lib/widgets/header.dart`
- Class: `DocumentFooter`

Key properties:

- `pageNumber` – current page index (1‑based).
- `totalPages` – total number of pages/sections.
- `leading` – optional left‑side widget (typically a footer logo or branding).
- `trailing` – optional right‑side widget.
- `onTap` – optional callback; when provided, the entire footer area is clickable.

In the blank document editor:

- `pageNumber` is `index + 1`.
- `totalPages` is `_sections.length`.
- If `_footerLogoUrl` is set, `leading` is an `Image.network` built from that URL.
- `onTap` is wired to `_pickFooterLogo()`, which opens the content library.

Behavior:

- The footer always shows a **page counter**: `Page X of Y` (when both values are available).
- Clicking the footer opens the **Content Library** dialog.
- When the user selects an image item, `_handleImageForBranding()` can set it as the **footer logo**.
- The same footer logo appears on **every A4 page**.

## Logo Storage and Persistence

The header and footer logo URLs are stored in state on the editor page:

- `_headerLogoUrl` – URL for the header logo.
- `_footerLogoUrl` – URL for the footer logo.

When the document is serialized in `_serializeDocumentContent()`, these values are written into the `metadata` block:

```jsonc
"metadata": {
  "currency": "...",
  "version": 1,
  "last_modified": "...",
  "headerLogoUrl": "https://...",
  "footerLogoUrl": "https://..."
}
```

On load, `_loadProposalFromDatabase()` reads these metadata fields and restores `_headerLogoUrl` and `_footerLogoUrl`, so logos persist across sessions.

## Content Library Integration (Branding Images)

The editor integrates with the content library in two ways:

1. **Uploads / Library side panel**
   - Clicking an image in the uploads or library list calls `_handleImageForBranding(imageUrl)`.
   - The user can choose whether to use the image as a **header logo**, **footer logo**, or **insert into page**.

2. **Clicking header/footer**
   - `onTap` on `DocumentHeader` / `DocumentFooter` calls `_pickHeaderLogo()` / `_pickFooterLogo()`.
   - Each method opens `ContentLibrarySelectionDialog` and, if the selected module is an image URL, passes it into `_handleImageForBranding()`.

This keeps all branding image decisions in one place while reusing the same UX for both header and footer.

## Summary

- Each A4 page is a fixed‑size canvas (`900 × 1273`) suitable for PDF‑style layouts.
- **Header** and **footer** are shared widgets used on every page.
- Logos are optional and come from the **content library**, not hard‑coded assets.
- Header/footer logos and configuration are persisted in the document `metadata`.
- The main editing experience happens in the page body, with support for text, tables, inline images, and background images.
