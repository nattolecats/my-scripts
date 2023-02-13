#!/bin/bash

sync() {
    export REPO_BRANCH=$(echo $(pwd) | awk -F "/" '{ print $NF }')
    
    echo "* Initializing '${REPO_BRANCH}'."
    repo init -u https://github.com/Evolution-X/manifest -b $REPO_BRANCH
    
    if [ $1 == "force" ]; then
        echo "* Force syncing."
        repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
    else
        echo "* Syncing."
        repo sync
    fi
}

build() {
    . build/envsetup.sh
    
    if [ $TARGET_PRODUCT == "" ]; then 
        lunch
    else
        lunch $TARGET_PRODUCT-userdebug
    fi
    
    export DEVICE=$(echo $TARGET_PRODUCT | sed -E 's/[a-z]+_//')
    
    unset EVO_BUILD_TYPE
    if [ $1 == "official" ]; then export EVO_BUILD_TYPE=OFFICIAL; fi
    
    m evolution
}

flash() {
    if [ $OUT == "" ]; then return
    
    if [ $(echo $(pwd) | awk -F "/" '{ print $NF }') == "tiramisu-pixel" ]; then
        adb reboot bootloader
    
        echo "* Flashing boot and vendor_boot..."
        
        fastboot flash boot $OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-eng.$USER/IMAGES/boot.img
        fastboot flash vendor_boot $OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-eng.$USER/IMAGES/vendor_boot.img
        fastboot reboot recovery
    else
        adb reboot recovery
    fi
    
    echo "* Waiting for sideload mode..."
    adb wait-for-sideload
    adb sideload $OUT/$(cd $OUT && ls *.zip | grep $TARGET_PRODUCT | tail -n 1)
}

upload() {
    export DEVICE=$1
    export DESTINATION=""
    export DESTINATION_IMG=""
    
    if [ $1 == "" ]; then export DEVICE=$(echo $TARGET_PRODUCT | sed -E 's/[a-z]+_//'); fi
    
    if [ $DEVICE == "" ]; then 
        echo "* Device codename is empty."
        return
    fi
    
    # Upload OTA zip
    if [ $EVO_BUILD_TYPE == "OFFICIAL" ]; then 
        export DESTINATION="evolution-x/${DEVICE}/"
        export DESTINATION="evolution-x/${DEVICE}/vendor_boot/"
    else 
        export DESTINATION="evolution-x-unofficial-builds/${DEVICE}/builds/"
        export DESTINATION="evolution-x-unofficial-builds/${DEVICE}/recovery_images/"
    fi
    
    scp $OUT/$(cd $OUT && ls *.zip | grep $TARGET_PRODUCT | tail -n 1) nattolecats@frs.sourceforge.net:/home/frs/p/$DESTINATION
    
    if [ $(echo $(pwd) | awk -F "/" '{ print $NF }') == "tiramisu-pixel" ]; then
        # Upload vendor_boot.img
        scp $OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-eng.$USER/IMAGES/vendor_boot.img nattolecats@frs.sourceforge.net:/home/frs/p/$DESTINATION
    
        # Upload boot.img
        scp $OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-eng.$USER/IMAGES/boot.img nattolecats@frs.sourceforge.net:/home/frs/p/$DESTINATION
    fi
}

echo "Scripts setting up."
