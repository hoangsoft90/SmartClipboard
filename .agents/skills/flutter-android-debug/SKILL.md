# Flutter Android Debug — ADB + Logcat

## Trigger
- User says "debug app", "app crash", "mở app lỗi", "check logcat"
- Any Flutter Android app that crashes or behaves unexpectedly on real device

## Overview
Debug Flutter app trên thiết bị Android thật qua adb. Cover common crash patterns và cách read logcat hiệu quả.

## Quick Debug Commands

### 1. Force restart app + capture logs
```bash
# Stop app, clear old logs, start fresh, capture 3 seconds
adb shell am force-stop <package_name>
adb logcat -c
adb shell am start -n <package_name>/.MainActivity
sleep 3
adb logcat -d -t 300 | grep -i "flutter\|error\|exception\|fatal"
```

### 2. Continuous monitoring (real-time)
```bash
adb logcat | grep -i "flutter\|error\|exception"
```

### 3. Filter by severity
```bash
# Errors only
adb logcat *:E | grep flutter

# Warnings + Errors
adb logcat *:W | grep flutter
```

### 4. Check app process
```bash
# Is app running?
adb shell pidof <package_name>

# Kill app
adb shell am force-stop <package_name>
```

### 5. Install APK directly
```bash
adb install -r path/to/app.apk
```

---

## Common Crash Patterns (Flutter Android)

### Pattern 1: Database PRAGMA crash
**Log**: `DatabaseException: Queries can be performed using SQLiteDatabase query or rawQuery methods only`
**Cause**: `db.execute('PRAGMA ...')` on Android sqflite
**Fix**: `db.rawQuery('PRAGMA ...')`

### Pattern 2: Missing import → type not found
**Log**: `'Database' isn't a type` or `'X' isn't a defined type`
**Cause**: Missing `import 'package:sqflite/sqflite.dart';`
**Fix**: Add import to every file using that type

### Pattern 3: Riverpod provider not found
**Log**: `ClassicError: A ProviderException was thrown ... UnimplementedError`
**Cause**: Provider throws in build() — often missing override in main()
**Fix**: Ensure `ProviderScope(overrides: [...])` wraps the app

### Pattern 4: Widget build error
**Log**: `A build function threw a ... Exception`
**Cause**: Runtime error inside `build()` method — null reference, type cast, etc.
**Fix**: Check the stack trace for exact line, wrap risky code in try-catch or null-check

### Pattern 5: MethodChannel not implemented
**Log**: `MissingPluginException: No implementation found for method X`
**Cause**: Native plugin not registered or wrong channel name
**Fix**: Check `MainActivity.kt` registers the channel, or plugin is in pubspec

### Pattern 6: SharedPreferences / file permission
**Log**: `FileSystemException: Operation not permitted` or `PathAccessException`
**Cause**: Missing storage permission or wrong path
**Fix**: Use `path_provider` instead of hardcoded paths; check permissions

### Pattern 7: Infinite widget rebuild
**Log**: App freezes, ANR (Application Not Responding)
**Cause**: `setState()` in `build()`, or provider circular dependency
**Fix**: Move setState to event handlers, check provider dependencies

### Pattern 8: Screen shows default Flutter demo
**Log**: No error — app runs but shows counter demo
**Cause**: `flutter create --overwrite` replaced `lib/main.dart`
**Fix**: Restore `lib/` from backup or git checkout

---

## Reading Logcat Effectively

### Good grep patterns
```bash
# Flutter-specific errors
adb logcat -d | grep -E "E/flutter|flutter.*error|exception"

# Crash stack traces (multi-line)
adb logcat -d | grep -A 20 "FATAL EXCEPTION"

# Database issues
adb logcat -d | grep -i "database\|sqlite\|sqflite"

# Plugin issues
adb logcat -d | grep -i "missingplugin\|methodchannel"

# UI/layout issues
adb logcat -d | grep -i "overflow\|renderflex\|layout"
```

### Bad practices (DON'T)
```bash
# DON'T: grep too broadly — will show thousands of irrelevant lines
adb logcat | grep "a"

# DON'T: forget to clear old logs first
adb logcat -d  # Shows ALL historical logs, confusing

# DON'T: ignore non-flutter errors that might affect your app
# (e.g., low memory, system kills)
```

---

## Debug Workflow

1. **Reproduce**: Force stop → clear logs → start app → wait 3s
2. **Capture**: `adb logcat -d -t 300 | grep -i "flutter\|error\|exception"`
3. **Read**: Find FIRST error (earliest timestamp) — that's usually the root cause
4. **Fix**: Apply the matching pattern from above
5. **Verify**: Repeat steps 1-2 after fix — no errors = good

## Pro Tips

- **First error is key**: Flutter errors cascade — fixing the first one often fixes the rest
- **Timestamp matters**: Errors with same timestamp are related
- **Check Warnings too**: Some warnings become errors on release builds
- **Release vs Debug**: Some issues only appear in release (e.g., tree-shaking removes unused code)
- **Hot reload doesn't help**: For native/DB issues, must do full restart
