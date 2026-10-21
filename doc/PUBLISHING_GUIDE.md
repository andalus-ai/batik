# Batik Framework - Publishing Guide

## ✅ Issue Fixed

The `publish_to` configuration error has been resolved.

### Problem
```yaml
publish_to: https://pub.dev  # ❌ Invalid - this is not a valid value
```

### Solution
```yaml
publish_to: none  # ✅ Correct for local development
```

## 📦 Package Structure

The Batik package now has the correct Flutter package structure:

```
batik/
├── pubspec.yaml              # ✅ Package configuration (root level)
├── lib/
│   ├── batik.dart            # ✅ Main library entry point
│   └── src/                  # ✅ Source code
│       ├── adapters/
│       ├── widgets/
│       ├── components/
│       └── ...
├── example/
│   ├── pubspec.yaml          # ✅ Example app configuration
│   └── lib/
│       └── main.dart         # ✅ Example application
├── test/                     # ✅ Unit tests
└── README.md                 # ✅ Documentation
```

## 🚀 Publishing to pub.dev

### When You're Ready to Publish

1. **Update pubspec.yaml**
   ```yaml
   # Remove or comment out this line:
   # publish_to: none
   
   # Update version
   version: 1.0.0  # Use semantic versioning
   ```

2. **Run dry-run first**
   ```bash
   cd wayang-ui/batik
   flutter pub publish --dry-run
   ```

3. **Check package score**
   ```bash
   flutter pub publish --dry-run
   # Visit https://pub.dev/packages/batik/score after publishing
   ```

4. **Publish**
   ```bash
   flutter pub publish
   ```

### Publishing Requirements

Before publishing to pub.dev, ensure:

- ✅ **Valid pubspec.yaml** - All required fields present
- ✅ **No analysis errors** - `flutter analyze` passes
- ✅ **Tests pass** - `flutter test` succeeds
- ✅ **Documentation** - README.md, example, comments
- ✅ **Version number** - Follows semantic versioning
- ✅ **Homepage/Repository** - Valid URLs
- ✅ **License** - Include LICENSE file

## 📋 Checklist for Publishing

### Code Quality
- [ ] No `flutter analyze` errors or warnings
- [ ] All tests pass (`flutter test`)
- [ ] Code is properly formatted (`dart format .`)
- [ ] No TODO comments in critical code
- [ ] All public APIs are documented

### Documentation
- [ ] README.md with usage examples
- [ ] CHANGELOG.md with version history
- [ ] API documentation (dartdoc comments)
- [ ] Example application
- [ ] Migration guide (if applicable)

### pubspec.yaml
- [ ] Correct `name` (lowercase, underscores)
- [ ] Valid `description` (1-2 sentences)
- [ ] Proper `version` (semantic versioning)
- [ ] `homepage` URL
- [ ] `repository` URL (optional but recommended)
- [ ] `issue_tracker` URL (optional but recommended)
- [ ] `environment` constraints
- [ ] All dependencies listed
- [ ] `publish_to` removed or set correctly

### Package Structure
- [ ] `lib/` directory with public API
- [ ] `lib/batik.dart` main entry point
- [ ] `example/` directory with working example
- [ ] `test/` directory with tests
- [ ] No unnecessary files in package

## 🔧 Development Workflow

### Local Development

For local development and testing:

```yaml
# pubspec.yaml
publish_to: none  # Keep this for local dev
```

### Using Local Package

In your Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  batik:
    path: ../batik  # Path to local batik package
```

### Testing Before Publishing

```bash
# 1. Run analyzer
flutter analyze

# 2. Run tests
flutter test

# 3. Format code
dart format .

# 4. Dry-run publish
flutter pub publish --dry-run

# 5. Check for issues
flutter pub outdated
```

## 📊 Package Score

After publishing, your package will be scored on pub.dev:

### Scoring Categories

1. **Analysis** (40 points)
   - No errors or warnings
   - Follow Dart/Flutter conventions

2. **Documentation** (40 points)
   - README.md
   - API documentation
   - Example code

3. **Dependency Management** (20 points)
   - Up-to-date dependencies
   - No conflicting dependencies

### Improving Score

- Add comprehensive documentation
- Include more examples
- Maintain regular updates
- Follow style guidelines
- Reduce dependencies

## 🎯 Version Management

### Semantic Versioning

```
MAJOR.MINOR.PATCH

1.0.0  - Initial release
1.0.1  - Bug fix
1.1.0  - New feature (backward compatible)
2.0.0  - Breaking change
```

### Version Guidelines

- **PATCH** (0.0.X): Bug fixes, no new features
- **MINOR** (0.X.0): New features, backward compatible
- **MAJOR** (X.0.0): Breaking changes

## 🔐 Authentication

### First-Time Publishing

1. **Login to pub.dev**
   ```bash
   flutter pub login
   ```

2. **Follow OAuth flow**
   - Opens browser
   - Sign in with Google account
   - Grant permissions

3. **Verify login**
   ```bash
   flutter pub whoami
   ```

### Multiple Publishers

Add additional publishers:

```bash
flutter pub add-publisher example@gmail.com
```

## 📝 Common Issues

### Issue: "publish_to" value is invalid

**Solution:** Remove or set to `none`:
```yaml
publish_to: none
```

### Issue: Package validation failed

**Solution:** Run analyzer and fix all issues:
```bash
flutter analyze
```

### Issue: Missing required field

**Solution:** Add missing fields to pubspec.yaml:
```yaml
description: Your package description
homepage: https://your-domain.com
```

### Issue: Version already exists

**Solution:** Increment version number:
```yaml
version: 1.0.1  # Was 1.0.0
```

## 🎉 Post-Publishing

### After Publishing

1. **Announce release**
   - Social media
   - Community forums
   - GitHub releases

2. **Monitor feedback**
   - GitHub issues
   - pub.dev likes/points
   - User feedback

3. **Maintain package**
   - Regular updates
   - Bug fixes
   - Feature requests

## 📚 Resources

- [Dart Package Guide](https://dart.dev/guides/libraries/create-packages)
- [Flutter Package Publishing](https://flutter.dev/docs/development/packages-and-plugins/developing-packages)
- [pub.dev Help](https://pub.dev/help)
- [Semantic Versioning](https://semver.org/)

## ✅ Current Status

- ✅ `publish_to` configuration fixed
- ✅ Package structure corrected
- ✅ Ready for local development
- ✅ Ready for testing
- ⏳ Ready for publishing (when you remove `publish_to: none`)

---

**Happy Publishing! 🚀**
