# Contributing to BitPoints

Thank you for your interest in contributing to BitPoints! This document provides guidelines to ensure your contributions are successful and don't break the CI/CD pipeline.

## Development Setup

### Prerequisites
- Node.js 22.x (LTS) - **Do NOT use Node.js 24.x** as it may cause compatibility issues
- npm or pnpm
- Git

### Installation
```bash
git clone https://github.com/bitpoints-cashu/bitpoints.me.git
cd bitpoints.me
npm ci
```

## Code Quality Checks

### Pre-commit Hooks (Recommended)
Set up pre-commit hooks to automatically check and fix issues:
```bash
# Install husky (if not already installed)
npm run prepare

# Or manually run checks before committing
npm run lint
npm run checkformat
npm run test:ci
```

### Automated Checks
The following checks run automatically on every push/PR:

#### 1. **Linting** (`npm run lint`)
- Uses ESLint with Vue 3 and TypeScript rules
- **Common Issues:**
  - Framework files in `/ios/`, `/android/`, `/src-capacitor/` are automatically ignored
  - Fix: `npm run lint:fix` or manually fix reported issues

#### 2. **Code Formatting** (`npm run checkformat`)
- Uses Prettier for consistent formatting
- **Common Issues:**
  - Files not formatted correctly
  - Fix: `npm run format` to auto-format all files

#### 3. **Testing** (`npm run test:ci`)
- Runs unit tests with Vitest
- Tests must pass on Node.js 22.x and 24.x
- **Common Issues:**
  - Test failures
  - Fix: Run tests locally with `npm run test` and fix failing tests

#### 4. **Build** (`npm run build`)
- Ensures the app builds successfully
- Tests both SPA and PWA builds
- **Common Issues:**
  - Compilation errors
  - Missing dependencies
  - Fix: Run `npm run build` locally and fix errors

## Development Workflow

### Before Making Changes
1. **Pull latest changes**: `git pull origin main`
2. **Create feature branch**: `git checkout -b feature/your-feature-name`
3. **Run checks locally**: Ensure all checks pass before committing

### Making Changes
1. **Write code** following the existing patterns
2. **Run local checks frequently**:
   ```bash
   npm run lint
   npm run checkformat
   npm run test:ci
   ```
3. **Format code**: `npm run format` before committing
4. **Test functionality** thoroughly

### Committing Changes
1. **Stage changes**: `git add .`
2. **Run checks again**: Ensure everything still passes
3. **Commit with clear message**:
   ```bash
   git commit -m "feat: add new feature description"
   # or
   git commit -m "fix: resolve issue description"
   git commit -m "docs: update documentation"
   ```

### Push & Create PR
1. **Push branch**: `git push origin feature/your-feature-name`
2. **Create Pull Request** with clear description
3. **Monitor GitHub Actions** - all checks must pass

## Common GitHub Actions Issues & Solutions

### 🔴 Linting Failures
**Error**: ESLint errors in framework files
**Cause**: iOS/Android framework files being linted
**Solution**:
- Files are automatically excluded via `.eslintignore`
- If new directories need exclusion, add them to `.eslintignore`
- Run `npm run lint` locally to check

### 🔴 Formatting Failures
**Error**: Prettier formatting issues
**Cause**: Code not formatted according to project standards
**Solution**:
```bash
npm run format  # Auto-format all files
npm run checkformat  # Verify formatting
```

### 🔴 Test Failures
**Error**: Unit tests failing
**Cause**: Code changes breaking existing functionality
**Solution**:
```bash
npm run test  # Run tests in watch mode for debugging
npm run test:ci  # Run tests as CI does
```

### 🔴 Build Failures
**Error**: Compilation errors
**Cause**: TypeScript errors, missing imports, syntax issues
**Solution**:
```bash
npm run build  # Build locally to see detailed errors
npm run dev  # Start dev server to check runtime issues
```

### 🔴 Node.js Version Issues
**Error**: Inconsistent Node.js versions across workflows
**Cause**: Different Node.js versions in workflow files
**Solution**:
- Use Node.js 22.x for all workflows (except where 24.x is explicitly tested)
- Update `.nvmrc` if needed: `echo "22" > .nvmrc`

## File Structure & Organization

### Important Files
- `.eslintignore` - Excludes framework/build files from linting
- `.prettierignore` - Excludes generated files from formatting
- `.eslintrc.js` - ESLint configuration
- `vitest.config.js` - Test configuration
- `quasar.config.js` - Build configuration

### Directories to Avoid Modifying
- `/ios/` - iOS build artifacts (auto-generated)
- `/android/` - Android build artifacts (auto-generated)
- `/dist/` - Build outputs (auto-generated)
- `/node_modules/` - Dependencies (auto-generated)

## Testing Guidelines

### Unit Tests
- Write tests for new features in `test/vitest/__tests__/`
- Use descriptive test names
- Test both success and failure cases
- Run `npm run test:ci` before committing

### Manual Testing
- Test in multiple browsers (Chrome, Firefox, Safari)
- Test on mobile devices
- Verify PWA functionality
- Test offline capabilities

## Brand-Specific Development

### Multi-Brand Support
The app supports multiple brands (BitPoints, Trails Coffee, etc.)

**Building specific brands:**
```bash
BRAND=bitpoints npm run build:pwa
BRAND=trails npm run build:pwa
```

**Testing different brands:**
```bash
BRAND=bitpoints npm run dev
BRAND=trails npm run dev
```

## Deployment

### PWA Packages
Create deployment packages for each brand:
```bash
npm run package:all  # Creates zip files for all brands
```

### Release Process
1. Create and push git tag: `git tag v1.x.x && git push origin v1.x.x`
2. GitHub Actions automatically builds release artifacts
3. Upload deployment packages to hosting providers

## Getting Help

- **Check existing issues** on GitHub
- **Read error messages** carefully - they often provide solutions
- **Run commands locally** before pushing to catch issues early
- **Ask in discussions** if you're stuck

## Checklist Before Pushing

- [ ] `npm run lint` passes
- [ ] `npm run checkformat` passes
- [ ] `npm run test:ci` passes
- [ ] `npm run build` succeeds
- [ ] Code follows existing patterns
- [ ] Documentation updated if needed
- [ ] Tested in target browsers

By following these guidelines, you'll help maintain code quality and prevent CI/CD failures! 🚀
