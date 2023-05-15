:: Adobe Product Cleanup Script for IUI University Library - AAB
:: Original script created 03-23-2023 by AAB
::===============================================

::Writing log file to indicate script has started running
echo %computername% - %time% - Started Adobe Product Cleanup script >>%windir%\Logs\AdobeProdCleanup.log

::Sets Variables for this script only
setlocal

::Variable Definitions
set logfile=%windir%\Logs\AdobeProdCleanup.log

::LogCheck - Checks to see if the AdobeProdCleanupComplete log exists and exits the scripts if it does
if exist %windir%\Logs\AdobeProdCleanupComplete.log ( 
    exit 
)

::ProductCheck - Checks for newest version of product. Writes to log file if product version does not exist. Goes to old product uninstaller if it does exist
:ProductCheck
if exist "C:\Program Files\Adobe\Adobe Audition 2023" (
    call :AuditionCleanup 
) else (
    echo Adobe Audtion 2023 not installed>> "%logfile%"
)

if exist "C:\Program Files\Adobe\Adobe Bridge 2023" ( 
    call :BridgeCleanup 
) else ( 
    echo Adobe Bridge 2023 not installed>> "%logfile%"
)

if exist "C:\Program Files\Adobe\Adobe Illustrator 2023" ( 
    call :IllustratorCleanup 
) else ( 
    echo Adobe Illustrator 2023 not installed>> "%logfile%"
)

if exist "C:\Program Files\Adobe\Adobe InDesign 2023" ( 
    call :InDesignCleanup 
) else (
    echo Adobe InDesign 2023 not installed>> "%logfile%"
)

if exist "C:\Program Files\Adobe\Adobe Media Encoder 2023" ( 
    call :EncoderCleanup 
) else (
    echo Adobe Media Encoder 2023 not installed>> "%logfile%"
)

if exist "C:\Program Files\Adobe\Adobe Photoshop 2023" ( 
    call :PhotoshopCleanup 
) else (
    echo Adobe Photoshop 2023 not installed>> "%logfile%"
)

if exist "C:\Program Files\Adobe\Adobe Premiere Pro 2023" ( 
    call :PremiereCleanup 
) else ( 
    echo Adobe Premiere 2023 not installed>> "%logfile%"
)

goto :Logging

::Cleanup - Checks for the folders created by older installations of Adobe products and uninstalls them if found. Then adds the information to the log file. 

:AuditionCleanup
if exist "C:\Program Files\Adobe\Adobe Audition 2022\" ( 
    wmic product where 'name like "Audition Shared %%"' call uninstall /nointeractive
    echo Adobe Audtion 2022 uninstalled>> "%logfile%" 
) else (
    echo Adobe Audition 2022 is not installed>>%logfile%
)
exit /b 0

:BridgeCleanup
if exist "C:\Program Files\Adobe\Adobe Bridge 2022\" ( 
    wmic product where 'name like "Bridge Shared %%"' call uninstall /nointeractive
    echo Adobe Bridge 2022 uninstalled>> "%logfile%" 
) else (
    echo Adobe Bridge 2022 is not installed>>%logfile%
)
exit /b 0

:IllustratorCleanup
if exist "C:\Program Files\Adobe\Adobe Illustrator 2022\" (
    wmic product where 'name like "Illustrator Shared %%"' call uninstall /nointeractive
    echo Adobe Illustrator 2022 uninstalled>> "%logfile%"
) else (
    echo Adobe Illustrator 2022 is not installed>>%logfile%
)
exit /b 0

:InDesignCleanup
if exist "C:\Program Files\Adobe\Adobe InDesign 2022\" (
    wmic product where 'name like "InDesign Shared %%"' call uninstall /nointeractive
    echo Adobe InDesign 2022 uninstalled>> "%logfile%"
) else (
    echo Adobe InDesign 2022 is not installed>>%logfile%
)
exit /b 0

:EncoderCleanup
if exist "C:\Program Files\Adobe\Adobe Media Encoder 2020" (
    rmdir "C:\Program Files\Adobe\Adobe Media Encoder 2020" /s /q
    del "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Media Encoder 2020.lnk"
    echo Adobe Media Encoder 2020 uninstalled>> "%logfile%" 
) else (
    echo Adobe Media Encoder 2020 is not installed>>%logfile%
)
exit /b 0

:PhotoshopCleanup
if exist "C:\Program Files\Adobe\Adobe Photoshop 2022\" (
    wmic product where 'name like "Photoshop Shared %%"' call uninstall /nointeractive
    rmdir "C:\Program Files\Adobe\Adobe Photoshop 2022\" /s /q
    echo Adobe Photoshop 2022 uninstalled>> "%logfile%" 
) else (
    echo Adobe Photoshop 2022 is not installed>>%logfile%
)
exit /b 0

:PremiereCleanup
if exist "C:\Program Files\Adobe\Adobe Premiere Pro 2022\" (
    wmic product where 'name like "Premiere Pro Shared %%"' call uninstall /nointeractive
    rmdir "C:\Program Files\Adobe\Adobe Premiere Pro 2022\" /s /q
    echo Adobe Premiere Pro 2022 uninstalled>> "%logfile%" 
) else (
    echo Adobe Premiere 2022 is not installed>>%logfile%
)
if exist "C:\Program Files\Adobe\Adobe Premiere Pro 2021\" (
    wmic product where 'name like "Adobe Premiere Pro %%" call uninstall /nointeractive
    rmdir "C:\Program Files\Adobe\Adobe Premiere Pro 2021\" /s /q
    echo Adobe Premiere Pro 2021 uninstalled>> "%logfile%" 
) else (
    echo Adobe Premiere 2021 is not installed>>%logfile%
)
exit /b 0

::Logging
::===============================================
:Logging
echo %date% - %time% - %computername% - AdobeCleanupScript completed > %windir%\Logs\AdobeProdCleanupComplete.log

endlocal