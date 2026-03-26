# Pigeon Technical Architecture

This document provides a detailed breakdown of Pigeon's technical stack, architecture, and development principles.

## 🧱 1. Tech Stack
- **Language**: Swift 6.0+
- **UI**: SwiftUI (with AppKit bridges where needed for precise control over menus, shortcuts, and windowing)
- **Architecture**: MVVM + modular services
- **Concurrency**: Swift Concurrency (async/await, actors)
- **Persistence**: File-based (YAML/JSON), following the Bruno-style data model for Git compatibility.

## 🧭 2. High-Level Architecture
```
App
├── Core
│   ├── Models
│   ├── Services
│   ├── Networking
│   ├── Storage
│   └── Utils
│
├── Features
│   ├── Workspace
│   ├── RequestEditor
│   ├── Environment
│   ├── Runner
│   └── History
│
├── UI
│   ├── Components
│   ├── Layout
│   └── Themes
│
└── Platform
    ├── Shortcuts
    ├── Windowing
    └── SystemIntegration
```

## 📂 3. File-Based Data Model
Pigeon aims for a simple, fast, and transparent data model.

### Workspace Structure
```
/MyWorkspace
  workspace.yaml
  environments/
    dev.yaml
    prod.yaml
  requests/
    user/
      get-user.yaml
      create-user.yaml
    auth/
      login.yaml
```

## ⚙️ 4. Core Modules

### 4.1 Workspace Manager
Handles folder loading, YAML parsing, and file-system watching for hot-reloads using `FileManager` and `DispatchSourceFileSystemObject`.

### 4.2 Request Engine
The `RequestBuilder` assembles `URLRequest` objects by:
1. Resolving `{{variables}}`
2. Merging headers
3. Attaching authentication
4. Encoding the body

### 4.3 Variable Resolution Engine
Supports dynamic interpolation of environment variables using standard double-brace syntax.

### 4.4 Networking Layer
Built on `URLSession` with support for timeouts and future interceptor capabilities.

## 🧠 5. State Management
Pigeon uses the modern Swift `Observation` framework (`@Observable`) for lightweight, reactive state management.

## ⚡ 6. Performance Strategy
- **Lazy Loading**: Requests are parsed only when needed.
- **Background Processing**: Heavy YAML parsing and network assembly are performed off the main thread.
- **Memory Efficiency**: Targeted memory footprint is <100MB RAM.

## 🧪 7. Roadmap
- **Phase 2**: Advanced scripting (Pre-request/Post-response), GraphQL support, and WebSockets.
- **Phase 3**: Enhanced Auth flows (OAuth 2.0), export to cURL/HTTPie, and full historical log.
