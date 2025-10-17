# Fixed: Circular Dependency Issue in arty.sh

## 🐛 Problem

The arty.sh template had an infinite loop issue when installing dependencies with circular references:

```
Project A → depends on → Project B
Project B → depends on → Project A
```

When running `arty deps`, the system would:
1. Install Project A
2. Read A's arty.yml and try to install B
3. Install Project B
4. Read B's arty.yml and try to install A
5. **Loop infinitely** between steps 2-4

---

## ✅ Solution Implemented

### 1. **Installation Stack Tracking**
Added a global associative array to track libraries currently being installed:

```bash
declare -g -A ARTY_INSTALL_STACK
```

### 2. **Circular Dependency Detection**
Before installing a library, check if it's already in the installation stack:

```bash
if is_installing "$lib_id"; then
    log_warn "Circular dependency detected: $lib_name"
    log_info "Skipping to prevent infinite loop"
    return 0
fi
```

### 3. **Already Installed Check**
Optimize by checking if library is already present before reinstalling:

```bash
if is_installed "$lib_name"; then
    log_info "Library '$lib_name' already installed"
    return 0
fi
```

### 4. **Stack Management**
Mark libraries as "installing" and unmark when done:

```bash
# Before installation
mark_installing "$lib_id"

# After installation
unmark_installing "$lib_id"
```

---

## 🔧 New Helper Functions

### `normalize_lib_id()`
Normalizes repository URLs for consistent tracking:
```bash
normalize_lib_id() {
    local repo_url="$1"
    # Convert to lowercase and remove .git suffix
    echo "${repo_url,,}" | sed 's/\.git$//'
}
```

**Why:** Different URL formats should be treated as the same library:
- `https://github.com/user/repo.git`
- `https://github.com/user/repo`
- `HTTPS://GITHUB.COM/USER/REPO.GIT`

All normalize to: `https://github.com/user/repo`

### `is_installing()`
Check if a library is currently being installed:
```bash
is_installing() {
    local lib_id="$1"
    [[ -n "${ARTY_INSTALL_STACK[$lib_id]:-}" ]]
}
```

### `mark_installing()` / `unmark_installing()`
Manage the installation stack:
```bash
mark_installing() {
    local lib_id="$1"
    ARTY_INSTALL_STACK[$lib_id]=1
}

unmark_installing() {
    local lib_id="$1"
    unset ARTY_INSTALL_STACK[$lib_id]
}
```

### `is_installed()`
Check if library already exists:
```bash
is_installed() {
    local lib_name="$1"
    [[ -d "$ARTY_LIBS_DIR/$lib_name" ]]
}
```

---

## 📊 Flow Comparison

### Before (Infinite Loop)
```
Install A
  ├─ Check A's references
  ├─ Install B
  │   ├─ Check B's references
  │   ├─ Install A ← 🔴 ALREADY INSTALLING
  │   │   ├─ Check A's references
  │   │   ├─ Install B ← 🔴 ALREADY INSTALLING
  │   │   │   └─ ... infinite loop ...
```

### After (Circular Detection)
```
Install A
  ├─ Mark A as installing
  ├─ Check A's references
  ├─ Install B
  │   ├─ Mark B as installing
  │   ├─ Check B's references
  │   ├─ Try to install A
  │   │   ├─ A is installing? YES ✓
  │   │   └─ Skip (circular dependency detected)
  │   └─ Unmark B
  └─ Unmark A

✅ Both libraries installed, no infinite loop
```

---

## 🎯 Example Scenarios

### Scenario 1: Simple Circular Reference

**Project A (arty.yml):**
```yaml
name: "project-a"
references:
  - https://github.com/user/project-b.git
```

**Project B (arty.yml):**
```yaml
name: "project-b"
references:
  - https://github.com/user/project-a.git
```

**Result:**
```bash
$ arty deps
[INFO] Installing reference: https://github.com/user/project-b.git
[INFO] Installing library: project-b
[INFO] Repository: https://github.com/user/project-b.git
[INFO] Found arty.yml, checking for references...
[INFO] Installing reference: https://github.com/user/project-a.git
[WARN] Circular dependency detected: project-a (already being installed)
[INFO] Skipping to prevent infinite loop
[SUCCESS] Library 'project-b' installed successfully
```

### Scenario 2: Transitive Circular Dependency

**A → B → C → A**

```bash
$ arty deps
[INFO] Installing A
  [INFO] Installing B
    [INFO] Installing C
      [WARN] Circular dependency detected: A
      [INFO] Skipping to prevent infinite loop
    [SUCCESS] C installed
  [SUCCESS] B installed
[SUCCESS] A installed
```

### Scenario 3: Already Installed

```bash
$ arty deps
[INFO] Installing reference: https://github.com/user/lib.git
[INFO] Library 'lib' already installed, checking for updates...
```

---

## 🛡️ Safety Features

### 1. **Non-destructive**
- Doesn't break existing installations
- Only prevents infinite loops

### 2. **Clear Messages**
- Users see exactly what's happening
- Warning when circular dependency detected
- Info when library already installed

### 3. **Continues on Circular Reference**
- Doesn't fail the entire installation
- Returns success (0) to continue with other dependencies
- Other libraries still get installed

### 4. **Update Support**
- Still checks for updates if library exists
- Uses quiet pull (`git pull -q`) for cleaner output
- Continues with existing version if update fails

---

## 📝 Code Changes Summary

### Modified Functions

#### `install_lib()`
**Before:** ~40 lines, no circular detection
**After:** ~70 lines, with:
- Circular dependency detection
- Already installed check
- Stack management
- Better error handling

### New Functions (5)
1. `normalize_lib_id()` - URL normalization
2. `is_installing()` - Check installation status
3. `mark_installing()` - Mark as installing
4. `unmark_installing()` - Unmark after installation
5. `is_installed()` - Check if already present

### New Global Variable
```bash
declare -g -A ARTY_INSTALL_STACK
```

---

## 🧪 Testing

### Test Case 1: Circular Dependency
```bash
# Create test projects
mkdir -p test-a test-b
cd test-a
cat > arty.yml << EOF
name: "test-a"
references:
  - ../test-b
EOF

cd ../test-b
cat > arty.yml << EOF
name: "test-b"
references:
  - ../test-a
EOF

# Test
cd ../test-a
arty deps
# Should complete without infinite loop
```

### Test Case 2: Self-Reference
```bash
cat > arty.yml << EOF
name: "self-ref"
references:
  - https://github.com/user/self-ref.git
EOF

arty deps
# Should detect and skip
```

### Test Case 3: Diamond Dependency
```bash
# A depends on B and C
# B and C both depend on D
# Should install D only once
```

---

## 💡 Technical Details

### Why Associative Array?
```bash
declare -g -A ARTY_INSTALL_STACK
```
- **Fast lookups**: O(1) complexity
- **Global scope**: `-g` flag ensures visibility across function calls
- **Associative**: `-A` allows string keys (URLs)
- **Boolean values**: Presence/absence indicates status

### URL Normalization
```bash
echo "${repo_url,,}" | sed 's/\.git$//'
```
- `${repo_url,,}` - Bash 4.0+ lowercase conversion
- `sed 's/\.git$//'` - Remove .git suffix
- **Result**: Consistent identifier for tracking

### Return Codes
- `return 0` on circular detection (success, skip)
- `return 1` on actual errors (clone failure)
- Allows other dependencies to continue installing

---

## 🎉 Benefits

### 1. **No More Infinite Loops**
- Circular dependencies are detected and handled gracefully
- Installation completes successfully

### 2. **Better Performance**
- Skips already installed libraries
- Quiet git pull for updates
- Fewer unnecessary operations

### 3. **Clear Feedback**
- Users see what's happening
- Warnings for circular dependencies
- Info messages for optimizations

### 4. **Robust Error Handling**
- Failures don't leave inconsistent state
- Stack is cleaned up on errors
- Other libraries continue installing

---

## 📚 Related Files

- `hammer.sh/templates/arty/arty.sh` - Main implementation
- `hammer.sh/templates/arty/arty.yml` - Example configuration
- `hammer.sh/templates/arty/README.md` - User documentation

---

## ✅ Checklist

- ✅ Circular dependency detection implemented
- ✅ Installation stack tracking added
- ✅ Already installed optimization added
- ✅ Helper functions created
- ✅ Error handling improved
- ✅ Warning messages added
- ✅ Documentation created
- ✅ Backward compatible
- ✅ Non-destructive
- ✅ Performance optimized

---

## 🚀 Usage

The fix is automatic - no user action required!

Users will see improved behavior:
```bash
$ arty deps
[INFO] Installing reference: https://github.com/user/lib-a.git
[INFO] Installing library: lib-a
[INFO] Found arty.yml, checking for references...
[INFO] Installing reference: https://github.com/user/lib-b.git
[INFO] Installing library: lib-b
[WARN] Circular dependency detected: lib-a (already being installed)
[INFO] Skipping to prevent infinite loop
[SUCCESS] Library 'lib-b' installed successfully
[SUCCESS] Library 'lib-a' installed successfully
```

**No more infinite loops!** 🎊
