# Development Workflow

This guide covers the Git workflow, commit conventions, and pull request process.

## Git Workflow

This project follows a **feature branch workflow**:

1. **Create a feature branch** from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and commit frequently:
   ```bash
   git add .
   git commit -m "feat: add product listing screen"
   ```

3. **Keep your branch up to date**:
   ```bash
   git checkout main
   git pull origin main
   git checkout feature/your-feature-name
   git merge main  # or git rebase main
   ```

4. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request** on GitHub/GitLab

## Branch Naming

Use the following naming convention:

```
<type>/<short-description>

Examples:
- feature/add-product-search
- fix/auth-token-refresh
- refactor/extract-common-widgets
- docs/update-onboarding-guide
- test/add-auth-integration-tests
```

**Types:**
- `feature/`: New features
- `fix/`: Bug fixes
- `refactor/`: Code refactoring
- `docs/`: Documentation changes
- `test/`: Test additions/changes
- `chore/`: Maintenance tasks

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Tests
- `chore`: Maintenance

**Examples:**
```bash
feat(auth): add token refresh functionality

fix(network): handle connection timeout errors

docs(guides): update onboarding instructions

refactor(products): extract product card widget

test(auth): add login use case tests
```

**Best Practices:**
- Use present tense ("add" not "added")
- Keep subject line under 50 characters
- Capitalize first letter of subject
- No period at end of subject
- Reference issues in footer: `Closes #123`

## PR Process

### Before Creating PR

- ✅ Code follows project conventions
- ✅ All tests pass (`flutter test`)
- ✅ Code analysis passes (`flutter analyze`)
- ✅ No linter errors
- ✅ Code is formatted (`dart format .`)
- ✅ Documentation updated (if needed)
- ✅ Branch is up to date with `main`

### PR Title

- Follow commit convention: `feat: add product search`
- Be descriptive and concise

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Feature
- [ ] Bug fix
- [ ] Documentation
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests pass locally
```

### Review Process

1. Address review comments
2. Make requested changes
3. Re-request review when ready
4. Wait for approval before merging

## Code Review Checklist

### For Reviewers

- [ ] Code follows architecture patterns
- [ ] Error handling is appropriate
- [ ] Tests are adequate
- [ ] No hardcoded values (use configuration)
- [ ] No security issues (tokens, passwords)
- [ ] Performance considerations addressed
- [ ] Documentation is clear
- [ ] No unnecessary dependencies
- [ ] Code is readable and maintainable

### For Authors

- [ ] Self-review completed
- [ ] All tests pass
- [ ] Code is formatted
- [ ] No linter errors
- [ ] Documentation updated
- [ ] PR description is clear
- [ ] Ready for review

## Next Steps

- ✅ Review [Common Tasks](../features/common-tasks.md) for development patterns
- ✅ Check [Troubleshooting](../support/troubleshooting.md) if you encounter issues

