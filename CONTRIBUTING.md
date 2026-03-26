# Contributing to Pigeon

First off, thank you for considering contributing to Pigeon! It's people like you who make Pigeon better for everyone.

## Code of Conduct

Please be respectful and inclusive in all your interactions within this project.

## How Can I Contribute?

### Reporting Bugs
- Use the **Bug Report** template when creating an issue.
- Provide a clear and concise description of the bug.
- Include steps to reproduce the behavior.

### Suggesting Enhancements
- Use the **Feature Request** template.
- Explain why the feature would be useful and how it should work.

### Pull Requests
1. Fork the repository.
2. Create a new branch: `git checkout -b feature/my-new-feature`
3. Make your changes and commit them: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/my-new-feature`
5. Submit a pull request.

## Development Setup

To build the project locally, you will need Xcode and `make`.

```bash
make build
```

To create a DMG:
```bash
make dmg
```

## Releasing

If you are a maintainer, you can release a new version using:
```bash
make release
```
This will guide you through tagging and pushing a new version.
