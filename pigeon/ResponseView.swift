//
//  ResponseView.swift
//  pigeon
//
//  Created by Antigravity on 19/03/2026.
//

import SwiftUI

struct ResponseView: View {
    let response: Response
    @Bindable var appState: AppState
    
    @State private var selectedTab: Int = 0
    @State private var showRaw: Bool = false
    
    // Search State
    @State private var isSearchVisible: Bool = false
    @State private var searchText: String = ""
    @State private var searchResultsCount: Int = 0
    @State private var currentSearchIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 60)
                .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            VStack(spacing: 0) {
                HStack {
                    Picker("", selection: $selectedTab) {
                        Text("Body").tag(0)
                        if isHTML {
                            Text("Preview").tag(2)
                        }
                        Text("Headers").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: isHTML ? 220 : 150)
                    
                    Spacer()
                    
                    if selectedTab == 0 && !response.body.isEmpty {
                        Toggle("Raw", isOn: $showRaw)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if selectedTab == 0 {
                    ZStack(alignment: .topTrailing) {
                        bodyTab
                        
                        if isSearchVisible {
                            searchBarOverlay
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .padding(.top, 8)
                                .padding(.trailing, 24)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchVisible)
                } else if selectedTab == 2 {
                    previewTab
                } else {
                    headersTab
                }
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(NotificationCenter.default.publisher(for: .triggerResponseSearch)) { _ in
            withAnimation {
                isSearchVisible = true
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeResponseSearch)) { _ in
            withAnimation {
                isSearchVisible = false
                isSearchFocused = false
                searchText = ""
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 20) {
            statusBadge
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TIME")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Text("\(Int(response.executionTime * 1000))ms")
                    .font(.subheadline.monospacedDigit())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("SIZE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Text(formattedSize)
                    .font(.subheadline.monospacedDigit())
            }
            
            if let contentType = response.contentType {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TYPE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    Text(contentType.components(separatedBy: ";").first ?? contentType)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            LayoutPickerView(appState: appState)
        }
        .padding(.horizontal)
    }
    
    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: response.size)
    }
    
    private var statusBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("STATUS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Text("\(response.statusCode)")
                .font(.subheadline.bold())
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch response.statusCode {
        case 200...299: return .green
        case 400...499: return .orange
        case 500...599: return .red
        default: return .secondary
        }
    }
    
    private var isHTML: Bool {
        response.contentType?.lowercased().contains("text/html") ?? false
    }
    
    private var previewTab: some View {
        WebView(html: response.body)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            )
    }
    
    private var bodyTab: some View {
        JSONCodeView(
            json: response.body,
            isRaw: showRaw,
            contentType: response.contentType,
            searchText: isSearchVisible ? searchText : "",
            currentSearchIndex: $currentSearchIndex,
            totalResults: $searchResultsCount
        )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            )
    }
    
    private var headersTab: some View {
        VStack(spacing: 0) {
            if response.headers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No Headers")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        ForEach(response.headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            GridRow {
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .bold()
                                    .foregroundColor(.secondary)
                                    .gridColumnAlignment(.leading)
                                
                                Text(value)
                                    .font(.system(.body, design: .monospaced))
                                    .multilineTextAlignment(.leading)
                            }
                            Divider()
                                .gridCellColumns(2)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private var searchBarOverlay: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($isSearchFocused)
                    .frame(width: 150)
                    .stopNewlineEntry(text: $searchText)
                    .onExitCommand {
                        withAnimation {
                            isSearchVisible = false
                            isSearchFocused = false
                            searchText = ""
                        }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            if searchResultsCount > 0 {
                Text("\(currentSearchIndex + 1) of \(searchResultsCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if !searchText.isEmpty {
                Text("No matches")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 0) {
                Button(action: { 
                    if currentSearchIndex > 0 {
                        currentSearchIndex -= 1
                    } else {
                        currentSearchIndex = max(0, searchResultsCount - 1)
                    }
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                
                Button(action: {
                    if currentSearchIndex < searchResultsCount - 1 {
                        currentSearchIndex += 1
                    } else {
                        currentSearchIndex = 0
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            
            Button(action: {
                withAnimation {
                    isSearchVisible = false
                    searchText = ""
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Material.thin)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

