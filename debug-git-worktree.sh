#!/bin/bash
# ABOUTME: Debug git worktree issues in Claude Squad container

echo "🔍 Git Worktree Debug Information"
echo "=================================="

echo "📁 Current Directory:"
pwd
echo ""

echo "👤 Current User:"
whoami
id
echo ""

echo "🔧 Git Configuration:"
echo "Global config:"
git config --global --list | grep -E "(user|safe|core)" || echo "No relevant global config"
echo ""
echo "Local config:"
git config --local --list | grep -E "(user|safe|core)" || echo "No relevant local config"
echo ""

echo "📊 Git Status:"
git status --porcelain | head -10
echo "Total changes: $(git status --porcelain | wc -l)"
echo ""

echo "🌲 Git Worktrees:"
git worktree list || echo "No worktrees or error listing worktrees"
echo ""

echo "📂 Directory Permissions:"
ls -la | head -10
echo ""

echo "🗂️ Worktrees Directory:"
if [ -d "worktrees" ]; then
    ls -la worktrees/
    echo "Permissions: $(stat -c %a worktrees 2>/dev/null || stat -f %Mp%Lp worktrees)"
else
    echo "worktrees directory does not exist"
fi
echo ""

echo "🔐 Repository Safety:"
git config --get-all safe.directory || echo "No safe directories configured"
echo ""

echo "🧪 Test Worktree Creation:"
echo "Attempting to create a test worktree..."
TEST_BRANCH="test-worktree-$(date +%s)"
git checkout -b "$TEST_BRANCH" 2>/dev/null || echo "Failed to create test branch"
mkdir -p worktrees 2>/dev/null || echo "Failed to create worktrees directory"
git worktree add "worktrees/$TEST_BRANCH" "$TEST_BRANCH" 2>&1 || echo "Failed to create worktree"

# Clean up test
git worktree remove "worktrees/$TEST_BRANCH" 2>/dev/null || true
git branch -d "$TEST_BRANCH" 2>/dev/null || true

echo ""
echo "🎯 Claude Squad Debug:"
claude-squad debug 2>&1 || echo "Failed to run claude-squad debug"
echo ""

echo "📋 Claude Squad Configuration:"
echo "Config paths from claude-squad debug:"
claude-squad debug 2>&1 | grep -i "path\|directory\|config" || echo "No path information found"
echo ""

echo "📁 Home Directory Contents:"
ls -la $HOME/ | grep -E "(claude|\.config|\.local)" || echo "No Claude-related directories in home"
echo ""

echo "🔍 Looking for Claude Squad data in common locations:"
for dir in "$HOME/.claude-squad" "$HOME/.config/claude-squad" "$HOME/.local/share/claude-squad" "/tmp/claudesquad" "/tmp/claude-squad"; do
    if [ -d "$dir" ]; then
        echo "  ✓ Found: $dir"
        ls -la "$dir" | head -5
    else
        echo "  ✗ Not found: $dir"
    fi
done