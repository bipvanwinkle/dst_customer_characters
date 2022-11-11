# Zip up the mod
zip -r mod.zip .

# Copy zip file to mod location
cp ~/Programming/Personal/dst_customer_characters/bip/mod.zip ~/Library/Application\ Support/Steam/steamapps/common/Don\'t\ Starve\ Together/dontstarve_steam.app/Contents/mods/

# Unzip zip
unzip -o ~/Library/Application\ Support/Steam/steamapps/common/Don\'t\ Starve\ Together/dontstarve_steam.app/Contents/mods/mod.zip -d ~/Library/Application\ Support/Steam/steamapps/common/Don\'t\ Starve\ Together/dontstarve_steam.app/Contents/mods/bip
