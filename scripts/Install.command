#!/bin/zsh
set -eu
bundle_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
source_app="$bundle_dir/Palworld.app"
if [[ ! -d "$source_app" ]]; then source_app="$bundle_dir/../dist/Palworld.app"; fi
if [[ ! -d "$source_app" ]]; then print -u2 'Extract the full release archive first.'; exit 1; fi
if /usr/bin/pgrep -x Palworld >/dev/null; then print -u2 'Close Palworld before installing this runtime update.'; exit 1; fi
/usr/bin/codesign --verify --deep --strict "$source_app"
application_dir="$HOME/Applications"
destination="$application_dir/Palworld.app"
if [[ -e "$destination" ]]; then
    identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")
    if [[ "$identifier" != 'org.palworldmods.launcher' ]]; then
        print -u2 'A different app already exists at ~/Applications/Palworld.app. Move it before installing.'; exit 1
    fi
fi
mkdir -p "$application_dir"
staging=$(mktemp -d "$application_dir/.palworld-install.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
/usr/bin/ditto "$source_app" "$staging/Palworld.app"
/usr/bin/codesign --verify --deep --strict "$staging/Palworld.app"
if [[ -e "$destination" ]]; then
    mkdir -p "$HOME/.Trash"
    backup=$(mktemp -d "$HOME/.Trash/Palworld-previous.XXXXXX")
    mv -- "$destination" "$backup/Palworld.app"
fi
mv -- "$staging/Palworld.app" "$destination"
shortcut="$HOME/Desktop/Palworld.app"
if [[ -L "$shortcut" ]]; then
    if [[ "$(readlink "$shortcut")" != "$destination" ]]; then
        print 'Installed. The existing Desktop shortcut was preserved.'; exit 0
    fi
elif [[ -e "$shortcut" ]]; then
    print 'Installed. The existing Desktop item was preserved.'; exit 0
else
    ln -s "$destination" "$shortcut"
fi
print 'Installed. Open Palworld from your Desktop. Mods is available in Options.'
