#!/bin/sh

MD5=md5
SHA1=shasum
TAR=tar

CURRENT_DIR=`pwd`
TMP_DIR=/tmp
SVN_REPO=http://svn.ec-cube.net/open
ECCUBE_VERSION=${ECCUBE_VERSION:-"2.13.2"}
WRK_DIR=eccube-$ECCUBE_VERSION
SVN_TAGS=$SVN_REPO/tags

IIS_WRK_DIR="$WRK_DIR"-IIS-p1
IIS_MANIFEST=$IIS_WRK_DIR/manifest.xml
IIS_PARAMS=$IIS_WRK_DIR/parameters.xml
IIS_INSTALL_SQL=$IIS_WRK_DIR/install_mysql.sql
IIS_WEBCONF=$IIS_WRK_DIR/ec-cube/web.config
IIS_INDEX=$IIS_WRK_DIR/ec-cube/index.php
IIS_PATCH=`pwd`/iis.patch

DISTINFO=$CURRENT_DIR/distinfo.txt

if [ ! -d $TMP_DIR ]; then
    mkdir -p $TMP_DIR
fi

cd $TMP_DIR
echo "export $SVN_TAGS/$WRK_DIR repositories..."
svn export $SVN_TAGS/$WRK_DIR $WRK_DIR 1> /dev/null

echo "remove obsolete files..."
rm -rf $WRK_DIR/.setttings
rm -rf $WRK_DIR/.buildpath
rm -rf $WRK_DIR/.project
rm -rf $WRK_DIR/templates
rm -rf $WRK_DIR/convert.php
rm -rf $WRK_DIR/*.sh
rm -rf $WRK_DIR/php.ini
rm -rf $WRK_DIR/patches
rm -rf $WRK_DIR/html/test
rm -rf $WRK_DIR/test
rm -rf $WRK_DIR/tests
rm -rf $WRK_DIR/data/downloads/module/*
find $WRK_DIR -name "dummy" -print0 | xargs -0 rm -rf
find $WRK_DIR -name ".svn" -type d -print0 | xargs -0 rm -rf

echo "complession files..."

echo "create MS WebPI archive..."
mkdir $IIS_WRK_DIR
mv $WRK_DIR $IIS_WRK_DIR/ec-cube
cat << EOF > $IIS_MANIFEST
<msdeploy.iisapp>
  <iisApp path="ec-cube" />
  <dbmysql path="install_mysql.sql"
           commandDelimiter="//"
           removeCommandDelimiter="true"
           waitAttempts="7"
           waitInterval="3000" />
  <setAcl path="ec-cube"
          setAclAccess="Modify"
          setAclUser="anonymousAuthenticationUser" />
  <setAcl path="ec-cube/data"
          setAclAccess="Modify"
          setAclUser="anonymousAuthenticationUser" />
</msdeploy.iisapp>
EOF

cat << EOF > $IIS_PARAMS
<parameters>
  <parameter name="Application Path"
             description="アプリケーションをインストールする先の完全なサイト パス（例: Default Web Site/ec-cube）。"
             defaultValue="Default Web Site/ec-cube"
             tags="iisapp">
    <parameterEntry type="ProviderPath"
                    scope="iisapp"
                    match="ec-cube" />
  </parameter>
  <parameter name="SetAclParameter1"
             description="Sets the ACL on the html directory"
             defaultValue="{Application Path}"
             tags="Hidden">
    <parameterEntry type="ProviderPath"
                    scope="setAcl"
                    match="ec-cube$" />
  </parameter>
  <parameter name="SetAclParameter2"
             description="Sets the ACL on the data directory"
             defaultValue="{Application Path}/data"
             tags="Hidden">
    <parameterEntry type="ProviderPath"
                    scope="setAcl"
                    match="ec-cube/data$" />
  </parameter>
  <parameter name="Database Server"
             defaultValue="localhost"
             tags="MySQL, dbServer">
<parameterEntry type="TextFile"
                    scope="ec-cube\\\\data\\\\config\\\\config.php"
                    match="PlaceHolderForServer" />
<parameterEntry type="TextFile" 
		    scope="install_mysql.sql"
                    match="PlaceholderForDbServer" />
  </parameter>

  <parameter name="Database Name"
             defaultValue="eccube_db"
             tags="MySQL, dbName">
    <parameterEntry type="TextFile"
                    scope="install_mysql.sql"
                    match="PlaceHolderForDb" />
<parameterEntry type="TextFile"
                    scope="ec-cube\\\\data\\\\config\\\\config.php"
                    match="PlaceHolderForDb" />
  </parameter>

  <parameter name="Database Username"
             defaultValue="eccube_user"
             tags="MySQL, DbUsername">
    <parameterEntry type="TextFile"
                    scope="install_mysql.sql"
                    match="PlaceHolderForUser" />
<parameterEntry type="TextFile"
                    scope="ec-cube\\\\data\\\\config\\\\config.php"
                    match="PlaceHolderForUser" />
  </parameter>

  <parameter name="Database Password"
             tags="New, Password, MySQL, DbUserPassword">
    <parameterEntry type="TextFile"
                    scope="install_mysql.sql"
                    match="PlaceHolderForPassword" />
<parameterEntry type="TextFile"
                    scope="ec-cube\\\\data\\\\config\\\\config.php"
                    match="PlaceHolderForPassword" />
  </parameter>

<parameter name="WebMatrix Connection String"
             defaultValue="/* mysql://{Database Username}:{Database Password}@{Database Server}/{Database Name};*/"
             tags="Hidden">
    <parameterEntry kind="TextFile"
                    scope="\\\\data\\\\config\\\\webmatrix.php"
                    match="/\\*\\s*mysql://([^:]*):([^@]*)@([^/]*)/([^;]*);\\*/" />  </parameter>


  <parameter name="Database Administrator"
             defaultValue="root"
             tags="MySQL, DbAdminUsername">
  </parameter>
  <parameter name="Database Administrator Password"
             tags="Password, MySQL, DbAdminPassword">
  </parameter>

  <parameter name="Connection String"
             description="接続文字列"
             defaultValue="Server={Database Server};Database={Database Name};uid={Database Administrator};Pwd={Database Administrator Password};"
             tags="Hidden">
    <parameterEntry type="ProviderPath"
                    scope="dbmysql"
                    match="install_mysql.sql" />
  </parameter>
</parameters>
EOF

cat << EOF > $IIS_INSTALL_SQL
USE PlaceHolderForDb;

DROP PROCEDURE IF EXISTS add_user ;

CREATE PROCEDURE add_user()
BEGIN
DECLARE EXIT HANDLER FOR 1044 BEGIN END;
GRANT ALL PRIVILEGES ON PlaceHolderForDb.* to 'PlaceHolderForUser'@'PlaceholderForDbServer' IDENTIFIED BY 'PlaceHolderForPassword';
FLUSH PRIVILEGES;
END
//

CALL add_user() //

DROP PROCEDURE IF EXISTS add_user //
EOF

cat << EOF > $IIS_WEBCONF
<configuration>
  <system.webServer>
    <security>
      <requestFiltering>
        <denyUrlSequences>
          <add sequence="/data" />
        </denyUrlSequences>
      </requestFiltering>
    </security>
    <defaultDocument>
      <!-- Set the default document -->
      <files>
        <clear />
        <add value="index.php" />
      </files>
    </defaultDocument>
  </system.webServer>
</configuration>
EOF

cd $IIS_WRK_DIR
patch -p0 < $IIS_PATCH
mv $IIS_PATCH ec-cube
mv ec-cube/html/* ec-cube
rm -r ec-cube/html
find . -name ".htaccess" -delete
zip -r ../$IIS_WRK_DIR.zip . 1> /dev/null
cd ../
mv $IIS_WRK_DIR.zip $CURRENT_DIR/
rm -r $IIS_WRK_DIR

MD5_IIS=`$MD5 $CURRENT_DIR/$IIS_WRK_DIR.zip`
SHA1_IIS=`$SHA1 $CURRENT_DIR/$IIS_WRK_DIR.zip`

echo "MD5 ($IIS_WRK_DIR.zip) = $MD5_IIS" >> $DISTINFO
echo "SHA1 ($IIS_WRK_DIR.zip) = $SHA1_IIS" >> $DISTINFO

echo "finished successful!"
echo $CURRENT_DIR/$IIS_WRK_DIR.zip

cat $DISTINFO
