#!/bin/bash
# ABOUTME: Debug tmux issues specifically for Claude Squad in Docker container

echo "🔍 Claude Squad Tmux Debug Information"
echo "======================================"

echo "👤 User Information:"
echo "  User: $(whoami)"
echo "  UID: $(id -u)"
echo "  GID: $(id -g)"
echo "  Groups: $(groups)"
echo ""

echo "🌍 Environment Variables:"
echo "  TERM: ${TERM:-not set}"
echo "  COLORTERM: ${COLORTERM:-not set}"
echo "  TMUX_TMPDIR: ${TMUX_TMPDIR:-not set}"
echo "  HOME: ${HOME:-not set}"
echo ""

echo "📁 Tmux Socket Directory:"
TMUX_SOCKET_DIR="/tmp/tmux-$(id -u)"
echo "  Expected: $TMUX_SOCKET_DIR"
if [ -d "$TMUX_SOCKET_DIR" ]; then
    echo "  ✓ Directory exists"
    echo "  Permissions: $(ls -ld "$TMUX_SOCKET_DIR")"
    echo "  Contents:"
    ls -la "$TMUX_SOCKET_DIR" 2>/dev/null || echo "    (empty or no access)"
else
    echo "  ✗ Directory does not exist"
fi
echo ""

echo "🔧 Tmux Configuration:"
echo "  Tmux version: $(tmux -V 2>/dev/null || echo 'not available')"
echo "  Default tmux socket: $(tmux display-message -p '#{socket_path}' 2>/dev/null || echo 'no active session')"
echo ""

echo "📊 Current Tmux Sessions:"
tmux list-sessions 2>/dev/null || echo "  No sessions or tmux server not running"
echo ""

echo "🧪 Test Basic Tmux Operations:"
echo "1. Creating test session..."
TEST_SESSION="debug-test-$(date +%s)"
if tmux new-session -d -s "$TEST_SESSION" 'echo "Test session started"; sleep 5'; then
    echo "  ✓ Session created successfully"
    
    echo "2. Testing pane capture..."
    if tmux capture-pane -p -t "$TEST_SESSION" 2>/dev/null; then
        echo "  ✓ Pane capture works"
    else
        echo "  ✗ Pane capture failed with exit code: $?"
        echo "  Stderr output:"
        tmux capture-pane -p -t "$TEST_SESSION" 2>&1 || true
    fi
    
    echo "3. Session info:"
    tmux list-sessions | grep "$TEST_SESSION" || echo "  Session not found in list"
    
    echo "4. Pane info:"
    tmux list-panes -t "$TEST_SESSION" 2>/dev/null || echo "  Could not list panes"
    
    echo "5. Cleaning up test session..."
    tmux kill-session -t "$TEST_SESSION" 2>/dev/null || echo "  Failed to kill test session"
else
    echo "  ✗ Failed to create test session"
fi
echo ""

echo "🔍 Claude Squad Process Check:"
if pgrep -f claude-squad >/dev/null; then
    echo "  Claude Squad is running:"
    ps aux | grep claude-squad | grep -v grep
else
    echo "  Claude Squad is not running"
fi
echo ""

echo "📋 System Tmux Processes:"
ps aux | grep tmux | grep -v grep || echo "  No tmux processes found"
echo ""

echo "🔐 File Permissions in /tmp:"
ls -la /tmp/ | grep tmux || echo "  No tmux directories in /tmp"
echo ""

echo "🧩 Test Claude Squad Tmux Commands:"
echo "Testing the exact commands Claude Squad would use..."

# Try to replicate what Claude Squad does
CLAUDE_SESSION="claudesquad_test_session"
echo "1. Creating Claude Squad style session: $CLAUDE_SESSION"
if tmux new-session -d -s "$CLAUDE_SESSION" -c "$(pwd)" 'bash'; then
    echo "  ✓ Claude Squad style session created"
    
    echo "2. Testing Claude Squad capture command..."
    echo "  Command: tmux capture-pane -p -e -J -t $CLAUDE_SESSION"
    if output=$(tmux capture-pane -p -e -J -t "$CLAUDE_SESSION" 2>&1); then
        echo "  ✓ Capture successful, output length: ${#output} chars"
    else
        exit_code=$?
        echo "  ✗ Capture failed with exit code: $exit_code"
        echo "  Error output: $output"
    fi
    
    echo "3. Testing extended capture..."
    echo "  Command: tmux capture-pane -p -e -J -S -10 -E 10 -t $CLAUDE_SESSION"
    if output=$(tmux capture-pane -p -e -J -S -10 -E 10 -t "$CLAUDE_SESSION" 2>&1); then
        echo "  ✓ Extended capture successful"
    else
        exit_code=$?
        echo "  ✗ Extended capture failed with exit code: $exit_code"
        echo "  Error output: $output"
    fi
    
    echo "4. Cleaning up Claude Squad test session..."
    tmux kill-session -t "$CLAUDE_SESSION" 2>/dev/null || echo "  Failed to kill Claude Squad test session"
else
    echo "  ✗ Failed to create Claude Squad style session"
fi
echo ""

echo "🎯 Running Claude Squad Debug Mode:"
if command -v claude-squad >/dev/null 2>&1; then
    echo "Claude Squad debug output:"
    timeout 10s claude-squad debug 2>&1 || echo "  Debug command timed out or failed"
else
    echo "  claude-squad command not found in PATH"
fi
echo ""

echo "📝 Recommendations:"
echo "  If pane capture is failing:"
echo "  1. Check tmux socket permissions in $TMUX_SOCKET_DIR"
echo "  2. Ensure TMUX_TMPDIR environment variable is set"
echo "  3. Try running 'tmux kill-server' and restart"
echo "  4. Check if container user has proper permissions"