# File Guide

## /Users/emilysmith/Desktop/The_Dump_iOS/file_guide.md
- Added: 2026-02-03 15:15:18 -0500
- Purpose: Central index of file purposes and dependencies.
- Imports: None.
- Imported by: None.

## /Users/emilysmith/Desktop/The_Dump_iOS/The_Dump/Models/NoteModels.swift
- Purpose: Note and category API models with preview, detail, and category fetch/update types.
- Imports: Foundation.
- Imported by: `The_Dump/Services/NotesService.swift`, `The_Dump/State/NotesListViewModel.swift`, `The_Dump/State/NoteDetailViewModel.swift`, `The_Dump/Views/NotesListView.swift`, `The_Dump/Views/NoteDetailView.swift`, `The_Dump/Views/BrowseView.swift`.

## /Users/emilysmith/Desktop/The_Dump_iOS/The_Dump/Services/NotesService.swift
- Purpose: Notes API networking for list, detail, edit, and category fetch.
- Imports: Foundation, os.log (DEBUG).
- Imported by: `The_Dump/State/NotesListViewModel.swift`, `The_Dump/State/NoteDetailViewModel.swift`.

## /Users/emilysmith/Desktop/The_Dump_iOS/The_Dump/Views/NotesListView.swift
- Purpose: Paginated list of note previews using API titles.
- Imports: SwiftUI.
- Imported by: `The_Dump/Views/BrowseView.swift`, `The_Dump/Views/BrowseFolderDestinationView.swift`.

## /Users/emilysmith/Desktop/The_Dump_iOS/The_Dump/Views/NoteDetailView.swift
- Purpose: Full note view using API title in navigation.
- Imports: SwiftUI, Combine.
- Imported by: `The_Dump/Views/NotesListView.swift`, `The_Dump/Views/BrowseView.swift`.

## /Users/emilysmith/Desktop/The_Dump_iOS/The_Dump/Views/BrowseView.swift
- Purpose: Folder list and search results using API titles in previews.
- Imports: SwiftUI.
- Imported by: `The_Dump/Views/MainTabView.swift`.
