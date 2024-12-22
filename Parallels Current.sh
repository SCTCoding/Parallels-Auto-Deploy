#! /bin/bash

parallelsKey="$4"

function logToFile {
	NOW=$(/bin/date +%s)
	NOWH=$(/bin/date "+%Y-%m-%d %H:%M:%S")
	logPath="$1"
	## $2 is the log text output which can be specified as a variable $log_text

	if [[ -f "$logPath" ]] && [[ $(/usr/bin/du -h "$logPath" | /usr/bin/awk '{print $1}' | /usr/bin/grep -c "M") -eq 1 ]] && [[ $(/usr/bin/du -h "$logPath" | /usr/bin/awk '{print $1}' | /usr/bin/grep -oE '^[0-9]{1,4}') -gt 20 ]]
	then
		echo "ROTATED: $NOW" > "$logPath"
		echo "STARTED: $NOW" >> "$logPath"
		echo "$NOW $NOWH $2" >> "$logPath"
		return
	elif [[ -f "$logPath" ]] && [[ $(/usr/bin/du -h "$logPath" | /usr/bin/awk '{print $1}' | /usr/bin/grep -cE "G|T|P|E") -eq 1 ]]
	then
		echo "ROTATED: $NOW" > "$logPath"
		echo "STARTED: $NOW" >> "$logPath"
		echo "$NOW $NOWH $2" >> "$logPath"
		return
	fi

	if [[ -f "$logPath" ]] && [[ $(/usr/bin/du -h "$logPath" | /usr/bin/awk '{print $1}' | /usr/bin/grep -cE 'B|K|M') -eq 1 ]]
	then
		echo "$NOW $NOWH $2" >> "$logPath"
		return
	else
		echo "STARTED: $NOW" >> "$logPath"
		echo "$NOW $NOWH $2" >> "$logPath"
		return 
	fi
}

## Obtain download URL
/usr/bin/curl --speed-time 20 --speed-limit 5000 -L "https://www.parallels.com/directdownload/pd/?mode=trial" -o "/private/tmp/temp.dmg"
mkdir "/private/tmp/obtainURL"
/usr/bin/hdiutil attach -nobrowse -noverify -mountPoint "/private/tmp/obtainURL" "/private/tmp/temp.dmg"

osVersion=$(/usr/bin/sw_vers -productVersion)
archVersion=$(/usr/bin/uname -m | /usr/bin/xargs)
prodShortVersion=$(/usr/bin/defaults read "/private/tmp/obtainURL/$(ls -1 /private/tmp/obtainURL/ | /usr/bin/grep -E "\.app$" | /usr/bin/head -n 1 | /usr/bin/xargs)/Contents/Info.plist" CFBundleShortVersionString)
prodVersion=$(/usr/bin/defaults read "/private/tmp/obtainURL/$(ls -1 /private/tmp/obtainURL/ | /usr/bin/grep -E "\.app$" | /usr/bin/head -n 1 | /usr/bin/xargs)/Contents/Info.plist" CFBundleVersion)

downloadURL=$(curl "https://desktop.parallels.com/api/v1/product_permissions?os=mac&os_version=${osVersion}&product_version=${prodShortVersion}-${prodVersion}&product_arch=${archVersion}&product_type=pdwi&product_locale=en_US&license_edition=3" | /usr/bin/awk -F ',' '{print $2}' | /usr/bin/awk -F '"' '{print $4}' | /usr/bin/xargs)

/usr/bin/hdiutil detach "/private/tmp/obtainURL"
rm -r "/private/tmp/obtainURL"
rm "/private/tmp/temp.dmg"

if [[ -z $downloadURL ]]
then
	echo "Failure. URL failed to be obtained..."
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels Automated Deployment failed to obtain the download URL. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
	exit 1
fi
##

function parallelsBuildDir {
	if [[ ! -d "/private/tmp/parallelsBuild" ]]
	then
		mkdir "/private/tmp/parallelsBuild"
	elif [[ -d "/private/tmp/parallelsBuild" ]]
	then
		echo "/private/tmp/parallelsBuild already exists..."
	fi
}

function obtainParallelsDeploy {
	attemptCount=0
	/usr/bin/curl --speed-time 20 --speed-limit 5000 -L "https://download.parallels.com/desktop/tools/pd-autodeploy.zip" -o "/private/tmp/parallelsBuild/parallelsAutoDeploy.zip"
	pdCurl=$?
	
	while [[ $attemptCount -lt 1 ]] && [[ $pdCurl -gt 0 ]]
	do
		/usr/bin/curl --speed-time 20 --speed-limit 5000 -L "https://download.parallels.com/desktop/tools/pd-autodeploy.zip" -o "/private/tmp/parallelsBuild/parallelsAutoDeploy.zip"
		pdCurl=$?
		attemptCount=$((attemptCount+1))
        sleep $((RANDOM % 20))
	done
	
	if [[ $pdCurl -gt 0 ]]
	then
		logToFile "/Library/${target}/CacheHandler.log" "parallelsAutoDeploy.zip failed to download with exit status $pdCurl."
		cleanUp
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels Automated Deployment failed to download. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
		exit 1
	elif [[ $pdCurl -eq 0 ]]
	then
		logToFile "/Library/${target}/CacheHandler.log" "parallelsAutoDeploy.zip completed with exit status $pdCurl."
	fi
}

function obtainParallelsDMG {
	attemptCount=0
	/usr/bin/curl --speed-time 20 --speed-limit 5000 -L "${downloadURL}" -o "/private/tmp/Parallels.dmg"
	dmgCurl=$?
	
	while [[ $attemptCount -lt 1 ]] && [[ $dmgCurl -gt 0 ]]
	do
		/usr/bin/curl --speed-time 20 --speed-limit 5000 -L "${downloadURL}" -o "/private/tmp/Parallels.dmg"
		dmgCurl=$?
		attemptCount=$((attemptCount+1))
        sleep $((RANDOM % 20))
	done
	
	if [[ $dmgCurl -gt 0 ]]
	then
		logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg failed with exit status $dmgCurl."
		cleanUp
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels Installer failed to download. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
		exit 1
	elif [[ $dmgCurl -eq 0 ]]
	then
		logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg completed with exit status $dmgCurl."
	fi
}

function verifyParallelsInstall {
	mkdir "/private/tmp/verifyParallels"
	
	/usr/bin/hdiutil attach -nobrowse -noverify -mountPoint "/private/tmp/verifyParallels" "/private/tmp/Parallels.dmg"
	
	downloadSign=$(/usr/bin/codesign -dv "/private/tmp/verifyParallels/$(ls -1 /private/tmp/verifyParallels/ | /usr/bin/grep -E "\.app$" | /usr/bin/head -n 1 | /usr/bin/xargs)" 2>&1 | /usr/bin/grep "TeamIdentifier=" | /usr/bin/awk -F= '{print $2}')
	
	/usr/bin/hdiutil detach "/private/tmp/verifyParallels"
	
	if [[ "$downloadSign" != "4C6364ACXT" ]]
	then
		echo "Code signature check failed. Failing..."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg has invalid code signature. Process failed."
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels installer downloaded has an invalid signature. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
		exit 1
	fi
    
    rm -r "/private/tmp/verifyParallels"
	
	logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg has a valid code signature."
}

function UnpackPD {
	if [[ $pdCurl -eq 0 ]]
	then
		/usr/bin/unzip -q "/private/tmp/parallelsBuild/parallelsAutoDeploy.zip" -d "/private/tmp/parallelsBuild/"
		fileName=$(ls "/private/tmp/parallelsBuild" | grep "mass deployment package")
		unzipStatus=$?
		logToFile "/Library/${target}/CacheHandler.log" "parallelsAutoDeploy.zip unpacked with status $unzipStatus"
	else
		echo "Curl of Parallels Auto Deploy failed..."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "parallelsAutoDeploy.zip failed to download. Process failing."
		exit 1
	fi
}

function moveDMGtoPD {
	if [[ $dmgCurl -eq 0 ]]
	then
		if [[ -e "/private/tmp/Parallels.dmg" ]]
		then
			mv "/private/tmp/Parallels.dmg" "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/Parallels Desktop DMG/Parallels.dmg"
		else
			echo "Parallels.dmg does not exist. Failing.."
			cleanUp
			logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg does not exist. Process failed."
			exit 1
		fi
	else
		echo "Curl of Parallels DMG failed..."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg curl failed. Process failed."
		exit 1
	fi
	
	logToFile "/Library/${target}/CacheHandler.log" "Parallels.dmg moved into place."
}

function configFile {
	#sed -i '' -e 's/license_key="XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX"/license_key="$license key"/g' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg"
	
	if [[ $(grep -c 'license_key="XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -eq 1 ]]
	then
		sed -i '' -e 's/license_key="XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX"/license_key="'"$parallelsKey"'"/g' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg"
	elif [[ $(grep -c 'license_key="XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -lt 1 ]]
	then
		echo "Unable to set the serial number."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "Unable to setup the deploy.cfg with license key. Process failed."
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels deployment configuration file has changed. Installation is unable to continue. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
		exit 1
	fi
	
	
	if [[ $(grep -c '#updates_url="None"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -eq 1 ]]
	then
		sed -i '' -e 's/#updates_url="None"/updates_url="Parallels"/g' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg"
	elif [[ $(grep -c '#updates_url="None"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -lt 1 ]]
	then
		echo "Unable set autoupdate server."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "Unable to setup the deploy.cfg with autoupdate server. Process failed."
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels deployment configuration file has changed. Installation is unable to continue. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
		exit 1
	fi
	
	
	if [[ $(grep -c '#updates_auto_check="2"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -eq 1 ]]
	then
		sed -i '' -e 's/#updates_auto_check="2"/updates_auto_check="1"/g' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg"
	elif [[ $(grep -c '#updates_auto_check="2"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -lt 1 ]]
	then
		echo "Unable set autoupdate to once per day."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "Unable to setup the deploy.cfg with autoupdate once per day. Process failed."
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels deployment configuration file has changed. Installation is unable to continue. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
		exit 1
	fi
	
	
	#if [[ $(grep -c '#updates_auto_download="on"/updates_auto_download="on"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -eq 1 ]]
	#then
	#	sed -i '' -e 's/#updates_auto_download="on"/updates_auto_download="on"/g' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg"
	#elif [[ $(grep -c '#updates_auto_download="on"' "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/License Key and Configuration/deploy.cfg") -lt 1 ]]
	#then
	#	echo "Unable set autoupdate to on."
	#	cleanUp
	#	logToFile "/Library/${target}/CacheHandler.log" "Unable to setup the deploy.cfg with autoupdate enabled. Process failed."
	#	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -title "ALERT" -description "The Parallels deployment configuration file has changed. Installation is unable to continue. Please contact the Service Desk for assistance." -timeout 120 -alignHeading center -icon /Library/Application\ Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns &
	#	exit 1
	#fi
	
	
	logToFile "/Library/${target}/CacheHandler.log" "deploy.cfg changes made."
}

function installParallels {
	if [[ -e "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg" ]] && [[ -e "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg/Parallels Desktop DMG/Parallels.dmg" ]]
	then
		/usr/sbin/installer -pkg "/private/tmp/parallelsBuild/$fileName/Parallels Desktop Autodeploy.pkg" -target /
		installStatus=$?
		
		logToFile "/Library/${target}/CacheHandler.log" "Parallels Desktop Autodeploy.pkg install completed with a status of $installStatus."
		
		if [[ $installStatus -gt 0 ]]
		then
			echo "Parallels Autodeploy package install failed..."
			cleanUp
			logToFile "/Library/${target}/CacheHandler.log" "Parallels Desktop Autodeploy.pkg failed to install. Process has failed completely."
		fi
	else
		echo "Parallels auto deploy build failed..."
		cleanUp
		logToFile "/Library/${target}/CacheHandler.log" "Parallels Desktop Autodeploy.pkg failed to install. Process has failed completely."
		exit 1
	fi
}

function enforceAutoUpdate {
	for user in /Users/*
	do
		if [[ -d "$user/Library/Preferences" ]] && [[ $(defaults read "$user/Library/Preferences/com.parallels.Parallels Desktop.plist" "Application preferences.Download updates automatically") != "1" ]]
		then
			sudo -u $(echo "$user" | awk -F/ '{print $3}') defaults write "$user/Library/Preferences/com.parallels.Parallels Desktop.plist" "Application preferences.Download updates automatically" -bool TRUE
		fi
	done
}

function cleanUp {
	if [[ -d "/private/tmp/parallelsBuild" ]]
	then
		rm -r "/private/tmp/parallelsBuild"
	fi
	
	if [[ -e "/private/tmp/Parallels.dmg" ]]
	then
		rm "/private/tmp/Parallels.dmg"
	fi
}

## MAIN
parallelsBuildDir &&

obtainParallelsDMG

obtainParallelsDeploy

verifyParallelsInstall &&

UnpackPD &&

moveDMGtoPD &&

configFile &&

installParallels &&

cleanUp

enforceAutoUpdate

exit 0