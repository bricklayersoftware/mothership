REM cmd /k F:\WORKING\hacking_WORK\DevOps\git_repo\tplmothership\contentversion_uploads\upload_file.bat

setlocal enabledelayedexpansion

set "CURRENT_DRIVE=%~d0"
echo The script is running from drive: %CURRENT_DRIVE%

set uploaddir=%CURRENT_DRIVE%\WORKING\hacking_WORK\DevOps\git_repo\tplmothership\contentversion_uploads
cd /d %uploaddir%

echo %CD%

IF NOT "%uploaddir%"=="%CD%" (
	pause
	exit
)

set mothership=https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault
REM set mothership=https://orgfarm-8e7ef9e5a3-dev-ed.develop.my.salesforce-sites.com/services/apexrest

type nul > curl.log
type nul > upload_list.txt

echo client_pubnub.html >> upload_list.txt

REM echo admin.html >> upload_list.txt
REM echo test_python_script.py >> upload_list.txt
REM echo cmd_list_test.bat >> upload_list.txt
REM echo cmd_list_snapshot_full.bat >> upload_list.txt
REM echo cmd_list_install_python.bat >> upload_list.txt
REM echo cmd_list_install_python_test_error_logging.bat >> upload_list.txt
REM echo cmd_list_test_python.bat >> upload_list.txt

set headers=-H "Content-Type: application/octet-stream"

for /f %%g in ( upload_list.txt ) do ( 
	echo processing %%g 

	set filename=%%g
	set filepath=%uploaddir%\!filename!

	IF EXIST "!filepath!" (
		echo uploading %%g 

		curl -i -v -ks -X POST %mothership%/upload.php?filename=!filename! %headers% --data-binary @"!filepath!" >> curl.log 2>&1
	) ELSE (
		echo file does not exist: !filepath!
	)

)

pause
exit