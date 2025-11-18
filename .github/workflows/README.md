# GitHub Actions Workflows

## Codecov Configuration

### For Private Repositories

1. **Get Codecov Token:**
   - Sign up at https://codecov.io
   - Add your repository
   - Copy your upload token

2. **Add Token to GitHub Secrets:**
   - Go to: `Settings > Secrets and variables > Actions`
   - Click `New repository secret`
   - Name: `CODECOV_TOKEN`
   - Value: Your Codecov token

3. **Workflow Configuration:**
   - The workflow is already configured for private repos (default)
   - No changes needed if using the private repository block

### For Public Repositories

1. **Comment out Private Repository Block:**
   In both `.github/workflows/test.yml` and `.github/workflows/coverage.yml`:
   ```yaml
   # Comment out this block:
   # - name: Upload to Codecov (Private)
   #   uses: codecov/codecov-action@v4
   #   ...
   #   token: ${{ secrets.CODECOV_TOKEN }}
   ```

2. **Uncomment Public Repository Block:**
   ```yaml
   # Uncomment this block:
   - name: Upload to Codecov (Public)
     uses: codecov/codecov-action@v4
     with:
       file: ./coverage/lcov.info
       flags: unittests
       name: codecov-umbrella
       fail_ci_if_error: false
       # No token needed for public repositories
   ```

3. **No Token Required:**
   - Public repositories don't need `CODECOV_TOKEN`
   - Codecov automatically detects public repos

## Quick Switch Guide

### Switch from Private to Public

1. Open `.github/workflows/test.yml`
2. Comment out the "PRIVATE REPOSITORY" block (lines ~77-85)
3. Uncomment the "PUBLIC REPOSITORY" block (lines ~87-96)
4. Repeat for `.github/workflows/coverage.yml`

### Switch from Public to Private

1. Get Codecov token and add to GitHub Secrets
2. Open `.github/workflows/test.yml`
3. Comment out the "PUBLIC REPOSITORY" block
4. Uncomment the "PRIVATE REPOSITORY" block
5. Repeat for `.github/workflows/coverage.yml`

## Workflows

### test.yml
- Runs on: push/PR to `main` or `develop`
- Actions:
  - Format check
  - Code analysis
  - Run tests with coverage
  - Generate HTML report
  - Check coverage threshold (80%)
  - Upload to Codecov
  - Comment PR with coverage summary

### coverage.yml
- Runs on: push/PR to `main` or manual trigger
- Actions:
  - Run tests with coverage
  - Calculate coverage metrics by layer
  - Upload to Codecov
  - Generate coverage badge
  - Comment PR with detailed analysis

## Troubleshooting

### Codecov Upload Fails

**For Private Repos:**
- Check if `CODECOV_TOKEN` is set in GitHub Secrets
- Verify token is valid at https://codecov.io
- Check token permissions

**For Public Repos:**
- Ensure repository is actually public
- Check Codecov supports your repository
- Verify no token is being used

### Coverage Not Showing

- Check workflow logs for errors
- Verify `coverage/lcov.info` is generated
- Check Codecov dashboard for upload status
- Ensure repository is connected to Codecov

