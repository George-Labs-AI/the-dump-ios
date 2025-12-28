import SwiftUI

struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.categoryRows.isEmpty && viewModel.dateGroupRows.isEmpty && viewModel.mimeTypeRows.isEmpty {
                        ProgressView("Loading…")
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        List {
                            if let error = viewModel.errorMessage {
                                Section {
                                    Text(error)
                                        .font(.system(size: Theme.fontSizeSM))
                                        .foregroundColor(Theme.accent)
                                }
                                .listRowBackground(Theme.darkGray)
                            }
                            
                            Section {
                                ForEach(viewModel.categoryRows) { row in
                                    NavigationLink {
                                        BrowseFolderDestinationView(kind: .category, name: row.name, count: row.count)
                                    } label: {
                                        BrowseFolderRowView(title: row.name, count: row.count)
                                    }
                                    .listRowBackground(Theme.darkGray)
                                }
                            } header: {
                                Text("Categories")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Section {
                                ForEach(viewModel.dateGroupRows) { row in
                                    NavigationLink {
                                        BrowseFolderDestinationView(kind: .dateGroup, name: row.name, count: row.count)
                                    } label: {
                                        BrowseFolderRowView(title: row.name, count: row.count)
                                    }
                                    .listRowBackground(Theme.darkGray)
                                }
                            } header: {
                                Text("Date Groups")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Section {
                                ForEach(viewModel.mimeTypeRows) { row in
                                    NavigationLink {
                                        BrowseFolderDestinationView(kind: .mimeType, name: row.name, count: row.count)
                                    } label: {
                                        BrowseFolderRowView(title: row.name, count: row.count)
                                    }
                                    .listRowBackground(Theme.darkGray)
                                }
                            } header: {
                                Text("File Types")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                        .refreshable {
                            await viewModel.loadCounts()
                        }
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.loadCounts()
            }
        }
    }
}

private struct BrowseFolderRowView: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            Text(title)
                .font(.system(size: Theme.fontSizeMD, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BrowseView()
}



