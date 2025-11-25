#!/bin/bash

# Script to generate Automator shortcuts for applications
# This creates shortcut apps that can be placed in the Dock without arrow overlays

set -e

# Configuration
SOURCE_DIRS=("/Applications" "/System/Applications")
SHORTCUTS_DIR="$HOME/AppShortcuts"
AUTOMATOR_STUB="/System/Library/CoreServices/Automator Application Stub.app/Contents/MacOS/Automator Application Stub"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create shortcuts directory if it doesn't exist
mkdir -p "$SHORTCUTS_DIR"

# Function to create the document.wflow file
create_workflow() {
    local target_app="$1"
    local workflow_file="$2"
    # Escape special characters for XML
    local escaped_app=$(echo "$target_app" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    cat > "$workflow_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <false/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.applescript.object</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>1.1.2</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMParameterProperties</key>
                <dict>
                    <key>appPath</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.applescript.object</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Launch Application.action</string>
                <key>ActionName</key>
                <string>Launch Application</string>
                <key>ActionParameters</key>
                <dict>
                    <key>appPath</key>
                    <string>$escaped_app</string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.Automator.RunApplication</string>
            </dict>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.application</string>
    </dict>
</dict>
</plist>
EOF
}

# Function to create Info.plist
create_info_plist() {
    local app_name="$1"
    local plist_file="$2"
    local bundle_id="com.automator.shortcut.$(echo "$app_name" | tr ' ' '.' | tr '[:upper:]' '[:lower:]')"
    
    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>Automator Application Stub</string>
    <key>CFBundleIconFile</key>
    <string>AutomatorApplet</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$app_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.5</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSMainNibFile</key>
    <string>ApplicationStub</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
}

# Function to extract icon from app bundle using macOS system tools
extract_icon_from_app() {
    local source_app="$1"
    local target_icns="$2"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Method 1: Use our Swift icon extractor (handles all apps including Assets.car)
    if [[ -f "$script_dir/extract_icon.swift" ]]; then
        if "$script_dir/extract_icon.swift" "$source_app" "$target_icns" &> /dev/null; then
            return 0
        fi
    fi
    
    # Method 2: Use fileicon tool if available (brew install fileicon)
    if command -v fileicon &> /dev/null; then
        if fileicon get "$source_app" "$target_icns" &> /dev/null; then
            return 0
        fi
    fi
    
    # Method 3: For modern apps with Assets.car, use generic icon as fallback
    if [[ -f "$source_app/Contents/Resources/Assets.car" ]]; then
        if [[ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]]; then
            cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" "$target_icns" && return 0
        fi
    fi
    
    return 1
}

# Function to extract and copy icon from source app
copy_app_icon() {
    local source_app="$1"
    local target_resources="$2"
    local icon_copied=false
    
    # Strategy 1: If app has Assets.car, prefer extracting from it (modern macOS apps)
    if [[ -f "$source_app/Contents/Resources/Assets.car" ]]; then
        if extract_icon_from_app "$source_app" "$target_resources/AutomatorApplet.icns"; then
            icon_copied=true
        fi
    fi
    
    # Strategy 2: Try to read CFBundleIconFile from Info.plist
    if [[ "$icon_copied" == false && -f "$source_app/Contents/Info.plist" ]]; then
        local icon_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$source_app/Contents/Info.plist" 2>/dev/null || echo "")
        
        if [[ -n "$icon_name" ]]; then
            # Add .icns extension if not present
            [[ "$icon_name" != *.icns ]] && icon_name="${icon_name}.icns"
            
            # Check if the icon file exists and is reasonable size (> 10KB)
            if [[ -f "$source_app/Contents/Resources/$icon_name" ]]; then
                local icon_size=$(stat -f%z "$source_app/Contents/Resources/$icon_name" 2>/dev/null || echo "0")
                if [[ $icon_size -gt 10240 ]]; then
                    cp "$source_app/Contents/Resources/$icon_name" "$target_resources/AutomatorApplet.icns"
                    icon_copied=true
                fi
            fi
        fi
    fi
    
    # Strategy 3: Look for any .icns file in Resources directory (fallback)
    if [[ "$icon_copied" == false && -d "$source_app/Contents/Resources" ]]; then
        # Look for the largest .icns file (likely to be the app icon)
        local icns_file=$(find "$source_app/Contents/Resources" -maxdepth 1 -name "*.icns" -exec ls -S {} + 2>/dev/null | head -1)
        
        if [[ -n "$icns_file" && -f "$icns_file" ]]; then
            cp "$icns_file" "$target_resources/AutomatorApplet.icns"
            icon_copied=true
        fi
    fi
    
    # Strategy 4: Use macOS to get the icon directly from the app bundle
    if [[ "$icon_copied" == false ]]; then
        # Use sips to extract icon - works for most apps including those with Assets.car
        if sips -s format icns "$source_app" --out "$target_resources/AutomatorApplet.icns" &>/dev/null; then
            icon_copied=true
        fi
    fi
    
    # If no icon found, copy default Automator icon
    if [[ "$icon_copied" == false ]]; then
        if [[ -f "/System/Library/CoreServices/Automator Application Stub.app/Contents/Resources/AutomatorApplet.icns" ]]; then
            cp "/System/Library/CoreServices/Automator Application Stub.app/Contents/Resources/AutomatorApplet.icns" "$target_resources/AutomatorApplet.icns"
        fi
    fi
    
    echo "$icon_copied"
}

# Function to check if shortcut needs updating
needs_update() {
    local shortcut_path="$1"
    local target_app="$2"
    
    # If shortcut doesn't exist, it needs creation
    [[ ! -d "$shortcut_path" ]] && return 0
    
    # Check if the workflow file exists and points to the correct app
    local workflow_file="$shortcut_path/Contents/document.wflow"
    if [[ -f "$workflow_file" ]]; then
        if grep -q "<string>$target_app</string>" "$workflow_file"; then
            return 1  # No update needed
        fi
    fi
    
    return 0  # Needs update
}

# Function to check if app should be visible (not a background helper)
is_visible_app() {
    local app_path="$1"
    local plist_path="$app_path/Contents/Info.plist"
    
    [[ ! -f "$plist_path" ]] && return 0  # No plist, assume visible
    
    # Check for LSUIElement (hides from Dock/Launchpad)
    local ui_element=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$plist_path" 2>/dev/null || echo "")
    [[ "$ui_element" == "true" || "$ui_element" == "1" ]] && return 1
    
    # Check for LSBackgroundOnly
    local bg_only=$(/usr/libexec/PlistBuddy -c "Print :LSBackgroundOnly" "$plist_path" 2>/dev/null || echo "")
    [[ "$bg_only" == "true" || "$bg_only" == "1" ]] && return 1
    
    return 0  # Visible app
}

# Function to create a shortcut for an application
create_shortcut() {
    local source_app="$1"
    local app_name=$(basename "$source_app" .app)
    local shortcut_path="$SHORTCUTS_DIR/${app_name}.app"
    
    # Skip if app is a background helper
    if ! is_visible_app "$source_app"; then
        return
    fi
    
    # Check if update is needed
    if ! needs_update "$shortcut_path" "$source_app"; then
        echo -e "${YELLOW}⊙${NC} $app_name (already up to date)"
        return
    fi
    
    # Remove existing shortcut if it exists
    [[ -d "$shortcut_path" ]] && rm -rf "$shortcut_path"
    
    # Create bundle structure
    mkdir -p "$shortcut_path/Contents/MacOS"
    mkdir -p "$shortcut_path/Contents/Resources"
    
    # Copy the Automator Application Stub executable
    if [[ -f "$AUTOMATOR_STUB" ]]; then
        cp "$AUTOMATOR_STUB" "$shortcut_path/Contents/MacOS/Automator Application Stub"
        chmod +x "$shortcut_path/Contents/MacOS/Automator Application Stub"
    else
        echo -e "${RED}✗${NC} Failed to find Automator Application Stub"
        return 1
    fi
    
    # Create workflow file
    create_workflow "$source_app" "$shortcut_path/Contents/document.wflow"
    
    # Create Info.plist
    create_info_plist "$app_name" "$shortcut_path/Contents/Info.plist"
    
    # Copy icon
    local icon_copied=$(copy_app_icon "$source_app" "$shortcut_path/Contents/Resources")
    
    # Copy essential Automator resources
    if [[ -f "/System/Library/CoreServices/Automator Application Stub.app/Contents/Resources/Assets.car" ]]; then
        cp "/System/Library/CoreServices/Automator Application Stub.app/Contents/Resources/Assets.car" "$shortcut_path/Contents/Resources/"
    fi
    
    # Set bundle bit
    /usr/bin/SetFile -a B "$shortcut_path" 2>/dev/null || true
    
    if [[ "$icon_copied" == "true" ]]; then
        echo -e "${GREEN}✓${NC} $app_name (with custom icon)"
    else
        echo -e "${GREEN}✓${NC} $app_name (with default icon)"
    fi
}

# Function to find all apps recursively (flattened)
find_all_apps() {
    for dir in "${SOURCE_DIRS[@]}"; do
        find "$dir" -name "*.app" -maxdepth 10 2>/dev/null
    done
}

# Function to clean up orphaned shortcuts
cleanup_orphaned_shortcuts() {
    echo ""
    echo "Cleaning up orphaned shortcuts..."
    
    local removed_count=0
    
    # Build list of all source app names once
    local source_app_names=""
    while IFS= read -r app_path; do
        local app_name=$(basename "$app_path" .app)
        source_app_names="$source_app_names|$app_name"
    done < <(find_all_apps)
    
    # Check each shortcut
    for shortcut in "$SHORTCUTS_DIR"/*.app; do
        [[ ! -d "$shortcut" ]] && continue
        
        local shortcut_name=$(basename "$shortcut" .app)
        
        # Check if corresponding source app exists
        if [[ ! "$source_app_names" =~ \|"$shortcut_name"(\||$) ]]; then
            echo -e "${RED}✗${NC} Removing orphaned shortcut: $shortcut_name"
            rm -rf "$shortcut"
            ((removed_count++))
        fi
    done
    
    if [[ $removed_count -eq 0 ]]; then
        echo -e "${GREEN}No orphaned shortcuts found${NC}"
    else
        echo -e "${YELLOW}Removed $removed_count orphaned shortcut(s)${NC}"
    fi
}

# Main execution
echo "========================================"
echo "App Shortcut Generator"
echo "========================================"
echo "Source: ${SOURCE_DIRS[*]}"
echo "Target: $SHORTCUTS_DIR"
echo ""

# Check if source directories exist
for dir in "${SOURCE_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Error: Source directory does not exist: $dir${NC}"
        exit 1
    fi
done

# Check if Automator Application Stub exists
if [[ ! -f "$AUTOMATOR_STUB" ]]; then
    echo -e "${RED}Error: Automator Application Stub not found at: $AUTOMATOR_STUB${NC}"
    exit 1
fi

echo "Processing applications..."
echo ""

# Process all applications
app_count=0
while IFS= read -r app_path; do
    create_shortcut "$app_path"
    ((app_count++))
done < <(find_all_apps)

echo ""
echo "Processed $app_count application(s)"

# Clean up orphaned shortcuts
cleanup_orphaned_shortcuts

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Your shortcuts are in: $SHORTCUTS_DIR"
echo "Drag this folder to your Dock to access your apps."
