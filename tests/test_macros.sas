/* Test requires .env file in cwd with the following variables:
    SITE_ID
    SITE_HOST
    DRIVE_ID
    FOLDER_ID
    AUTH_CODE

   Save all credentials for testing to ./tests/creds:
      - config.auth.json
      - config.secret.json

   DO NOT COMMIT .env OR ANY FILES IN THE CREDS FOLDER
*/

%let regex  = %sysfunc(prxparse(s/\\[^\\]*$//));
%let cwd    = %sysfunc(prxchange(&regex, 1, %sysfunc(dequote(&_SASPROGRAMFILE))));
%let parent = %sysfunc(prxchange(&regex, 1, &cwd));
%include "&parent/ms-graph-macros.sas";

/****************************************/
/********* Test using an auth code ******/
/****************************************/
%initConfig(configPath=&cwd/creds, configFilename=config.auth.json);

/* You must put your auth code in .env */
%generateAuthUrl;

data _null_;
    length var value $32767.;
    infile "&cwd/.env" dlm='=' dsd;
    input var$ value$;

    call symputx(var, value);
run;

%get_access_token(&auth_code, debug=1);

%initSessionMS365;

%listMyDrives;

%listSiteLibraries(siteHost=&site_host, sitePath=&site_path);

%uploadFile(
    driveId=&drive_id., 
    folderId=&folder_id.,
    sourcePath=&cwd.,
    sourcefilename=hello_world.txt
);

%listFolderItems(driveID=&drive_id, folderID=&folder_id);

data _null_;
    set folderitems;
    where name = 'hello_world.txt';

    call symputx('item_id', id);
run;

%downloadFile(
    driveID=&drive_id,
    folderID=&folder_id,
    sourceFileName=hello_world.txt,
    destinationPath=%sysfunc(getoption(work))
);

data _null_;
    infile "%sysfunc(getoption(work))/hello_world.txt";
    input;

    if (_N_ = 1) then do;
        put '*****************************';
        put 'Checking downloaded test file';
        put '*****************************';
    end;

    put _INFILE_;
run;

%getFileSensitivityLabel(driveId=&drive_id., itemId=&item_id.);
%getAllSensitivityLabels(driveId=&drive_id., folderId=&folder_id., out=labels);

/****************************************/
/****** Test using a client secret ******/
/****************************************/
%initConfig(configPath=&cwd/creds, configFilename=config.secret.json);

data _null_;
    length var value $32767.;
    infile "&cwd/.env" dlm='=' dsd;
    input var$ value$;

    call symputx(var, value);
run;

%initSessionMS365;

%listMyDrives;

%listSiteLibraries(siteHost=&site_host, sitePath=&site_path);

%uploadFile(
    driveId=&drive_id.,
    folderId=&folder_id.,
    sourcePath=&cwd.,
    sourcefilename=hello_world.txt
);

%listFolderItems(driveID=&drive_id, folderID=&folder_id);

data _null_;
    set folderitems;
    where name = 'hello_world.txt';

    call symputx('item_id', id);
run;

%downloadFile(
    driveID=&drive_id,
    folderID=&folder_id,
    sourceFileName=hello_world.txt,
    destinationPath=%sysfunc(getoption(work))
);

data _null_;
    infile "%sysfunc(getoption(work))/hello_world.txt";
    input;

    if (_N_ = 1) then do;
        put '*****************************';
        put 'Checking downloaded test file';
        put '*****************************';
    end;

    put _INFILE_;
run;

%getFileSensitivityLabel(driveId=&drive_id., itemId=&item_id.);
%getAllSensitivityLabels(driveId=&drive_id., folderId=&folder_id., out=labels);