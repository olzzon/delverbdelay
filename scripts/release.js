#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function getCurrentVersion() {
  const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  return packageJson.version;
}

function updateVersion(newVersion) {
  const packageJsonPath = path.join(process.cwd(), 'package.json');
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  packageJson.version = newVersion;
  fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
}

function incrementVersion(version, type) {
  const parts = version.split('.').map(Number);

  switch (type) {
    case 'major':
      parts[0]++;
      parts[1] = 0;
      parts[2] = 0;
      break;
    case 'minor':
      parts[1]++;
      parts[2] = 0;
      break;
    case 'patch':
      parts[2]++;
      break;
    default:
      throw new Error(`Invalid version type: ${type}`);
  }

  return parts.join('.');
}

function updateChangelog(version) {
  const changelogPath = path.join(process.cwd(), 'CHANGELOG.md');

  if (!fs.existsSync(changelogPath)) {
    // Create changelog if it doesn't exist
    const today = new Date().toISOString().split('T')[0];
    const changelog = `# Changelog

## [Unreleased]

<!-- Add new changes here -->

## [${version}] - ${today}

- Initial release
`;
    fs.writeFileSync(changelogPath, changelog);
    return;
  }

  const changelog = fs.readFileSync(changelogPath, 'utf8');
  const today = new Date().toISOString().split('T')[0];

  // Replace [Unreleased] with the new version
  const updatedChangelog = changelog.replace(
    '## [Unreleased]',
    `## [Unreleased]\n\n<!-- Add new changes here -->\n\n## [${version}] - ${today}`
  );

  fs.writeFileSync(changelogPath, updatedChangelog);
}

function updateCMakeLists(version) {
  const cmakePath = path.join(process.cwd(), 'CMakeLists.txt');
  const cmake = fs.readFileSync(cmakePath, 'utf8');

  // Update the VERSION in the project() command
  const updatedCMake = cmake.replace(
    /project\(DeliVerb VERSION \d+\.\d+\.\d+/,
    `project(DeliVerb VERSION ${version}`
  );

  fs.writeFileSync(cmakePath, updatedCMake);
}

function main() {
  const args = process.argv.slice(2);
  const releaseType = args[0];

  if (!['major', 'minor', 'patch'].includes(releaseType)) {
    log('Usage: node scripts/release.js [major|minor|patch]', 'red');
    log('', 'reset');
    log('  major: Breaking changes (1.0.0 -> 2.0.0)', 'yellow');
    log('  minor: New features (1.0.0 -> 1.1.0)', 'yellow');
    log('  patch: Bug fixes (1.0.0 -> 1.0.1)', 'yellow');
    process.exit(1);
  }

  try {
    // Check for uncommitted changes
    const status = execSync('git status --porcelain', { encoding: 'utf8' });
    if (status.trim()) {
      log('Warning: You have uncommitted changes!', 'yellow');
      log('Please commit or stash them before creating a release.', 'yellow');
      process.exit(1);
    }

    const currentVersion = getCurrentVersion();
    const newVersion = incrementVersion(currentVersion, releaseType);

    log('', 'reset');
    log('='.repeat(50), 'blue');
    log(`  Creating ${releaseType} release`, 'bright');
    log('='.repeat(50), 'blue');
    log('', 'reset');
    log(`Current version: ${currentVersion}`, 'yellow');
    log(`New version:     ${newVersion}`, 'green');
    log('', 'reset');

    // Update package.json
    log('Updating package.json...', 'blue');
    updateVersion(newVersion);

    // Update CMakeLists.txt
    log('Updating CMakeLists.txt...', 'blue');
    updateCMakeLists(newVersion);

    // Update CHANGELOG.md
    log('Updating CHANGELOG.md...', 'blue');
    updateChangelog(newVersion);

    log('', 'reset');
    log('Version updated successfully!', 'green');
    log('', 'reset');
    log('Next steps:', 'bright');
    log('  1. Review the changes in CHANGELOG.md and add any missing items', 'yellow');
    log('  2. Commit the changes: git add -A && git commit -m "chore: release v' + newVersion + '"', 'yellow');
    log('  3. Create a git tag: git tag v' + newVersion, 'yellow');
    log('  4. Build the release: ./scripts/build.sh', 'yellow');
    log('  5. Install and test: ./scripts/install.sh', 'yellow');
    log('  6. Build installer: ./scripts/build-installer.sh', 'yellow');
    log('  7. Push changes: git push && git push --tags', 'yellow');
    log('', 'reset');

  } catch (error) {
    log('Error: ' + error.message, 'red');
    process.exit(1);
  }
}

main();
