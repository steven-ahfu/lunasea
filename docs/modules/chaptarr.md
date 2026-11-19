---
title: Chaptarr
parent: Modules
---

# Chaptarr

In **Settings → Configuration → Chaptarr**, enable the module for the current LunaSea profile. Enter the Chaptarr server URL and its API key from **Settings → General** in Chaptarr. Include the URL prefix if you use a reverse proxy. Add any required custom headers and tap **Test Connection**.

Open **Chaptarr** from the drawer. Tap the book or headphones icon to switch between ebooks and audiobooks. In **Library**, search by title, filter your books, sort by title or author, or switch between **Block View** and **Grid View**. Selecting the active sort again reverses its direction.

Each book has **Overview**, **Files**, and **History** tabs. Tap the cover card to read the full synopsis, or tap the bookmark to change monitoring. Files lists the path, size, and quality reported by Chaptarr. History shows events for that book.

Tap the **pencil** on book details to open **Edit Book**. Change monitoring, automatic edition switching, or the selected edition, then tap **Update**. To pin a different edition of a book that already has files, turn off automatic edition switching first. **Author settings** opens a separate editor for the quality profile, metadata profile, root folder, author path, and tags shared by that author's books in the selected format.

Long-press a library card or use the details overflow menu to edit, monitor, refresh, preview file renames, or remove the book. The removal dialog lets you choose whether to delete its files and add an import list exclusion. The link icon opens the reference sites supplied by Chaptarr.

**Automatic** asks Chaptarr to select a release. **Interactive** opens the indexer results for that book. Search, filter, or sort the results and tap a row to see its details. The warning icon shows Chaptarr’s rejection reasons. **Download** sends the selected release to Chaptarr’s download client.

**Upcoming** shows releases in the next 30 days. **Missing** shows monitored books without files. Under **More**, open **Queue** for active downloads or **History** for activity across the library.

Tap a queue item to see its status, open the book, import a download, or remove it. Grabbed history events can be marked as failed. **More → Manual Import** lets you browse the server, run a quick import, or preview files and match them to a book and edition. **More → System Status** shows server health, disks, and root folders. **More → Tags** lets you create, rename, or remove tags. The library overflow menu includes RSS sync, search all missing for the current format, library refresh, backup, and the web interface.

The dashboard calendar includes Chaptarr releases. Use **Settings → Configuration → Dashboard → Calendar** to toggle them. To set up notifications, run the matching LunaSea notification service, copy the Chaptarr webhook URL from LunaSea's notification settings, and add it as a POST webhook under **Settings → Connect** in Chaptarr. Tapping a notification opens the corresponding book, queue, system status, or library.

To add a title, tap **+**, search for a book, and choose a format. Tap the result and choose the root folder. You can accept its default quality and metadata profiles, select other compatible profiles, and enable a release search on add. Tap **Add book**. You can return to search while the import runs. If the connection drops before Chaptarr confirms the import, tap **Check library** to check whether it finished. For a title already in the library, tap the search result to manage the local edition.
