//
//  SettingsView.swift
//  pigeon
//
//  Created by Antigravity on 21/03/2026.
//

import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "paintbrush"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SettingsCategory = .general
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsCategory.allCases) { category in
                    CategoryRow(category: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(.top, 40)
            .padding(.horizontal, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(selectedCategory.rawValue)
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedCategory {
                        case .general:
                            generalSettings
                        case .shortcuts:
                            shortcutSettings
                        case .about:
                            aboutSettings
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 500)
    }
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.headline)
                
                Picker("Theme", selection: $appState.selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                
                Text("Choose how PostGet looks to you. 'System' will follow your macOS appearance settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
        }
    }
    
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                ShortcutRow(label: "Settings", shortcut: "⌘ ,")
                Divider()
                ShortcutRow(label: "New Request", shortcut: "⌘ N")
                Divider()
                ShortcutRow(label: "Save Request", shortcut: "⌘ S")
                Divider()
                ShortcutRow(label: "Open File/Folder", shortcut: "⌘ O")
                Divider()
                ShortcutRow(label: "Close Tab", shortcut: "⌘ W")
                Divider()
                ShortcutRow(label: "Send Request", shortcut: "Return")
                Divider()
                ShortcutRow(label: "Sidebar Toggle", shortcut: "⌘ 0")
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var aboutSettings: some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            
            VStack(spacing: 4) {
                Text("PostGet")
                    .font(.title2.bold())
                Text("Version 1.0.0 (Build 1)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("A modern, fast, and beautiful API client for macOS.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Divider().frame(width: 200)
            
            Text("© 2026 Ashok Pokhrel")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20)
                .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
            
            Text(category.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        .cornerRadius(6)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: action)
        .contentShape(Rectangle())
    }
}

struct ShortcutRow: View {
    let label: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    SettingsView(appState: AppState())
}
