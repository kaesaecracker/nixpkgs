{ lib
, stdenv
, fetchurl
, makeWrapper
, dpkg
, autoPatchelfHook
# libs
, python37
, python37Packages
, readline81
, curl
, gobject-introspection
, gtk3
, libthai
, qt5 # qt5 packages
}:

stdenv.mkDerivation rec {
  pname = "insync";
  version = "3.8.4.50481";

  src = fetchurl {
    # Find a binary from https://www.insynchq.com/downloads/linux#ubuntu.
    #
    # Note: Ubuntu kinetic (22.10) uses glibc 2.36, which nixpkgs does not use yet.
    #       So we use jammy package instead.
    url = "https://cdn.insynchq.com/builds/linux/${pname}_${version}-jammy_amd64.deb";
    sha256 = "sha256-jd2/XB9UYhofvI7rDrjCTXtjJyo62JQtPo2t53kTjRs=";
  };

  postPatch = ''
    substituteInPlace usr/bin/insync --replace /usr/lib/insync $out/usr/lib/insync
  '';

  buildInputs = [
    python37
    readline81
    curl
    gobject-introspection
    gtk3
    libthai
  ] ++ (with qt5; [
    qtbase
    qtvirtualkeyboard
    qtlocation
    qtwebchannel
    qtwebengine
    qtwebsockets
    qtserialport
    qtwayland
  ]) ++ (with python37Packages; [
    pyside2
    shiboken2
  ]);

  nativeBuildInputs = [ autoPatchelfHook dpkg makeWrapper ];

  unpackPhase = ''
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share
    # delete dynamic libraries
    ls usr/lib/insync/lib{*.so,*.so.*} | xargs rm -f
    rm usr/lib/insync/nss -r
    rm usr/lib/insync/shiboken2/ -r
    rm usr/lib/insync/PySide2/ -r
    # copy files and link necessary modules
    cp -R usr/* $out/
    ln -s ${python37}/lib/libpython3.7m.so $out/lib/insync/libpython3.7m.so.1.0
    ln -s ${python37Packages.shiboken2}/lib/python3.7/site-packages/shiboken2 $out/lib/insync/shiboken2
    mkdir $out/lib/insync/PySide2/
    ln -s ${python37Packages.pyside2}/lib/python3.7/site-packages/PySide2/* $out/lib/insync/PySide2/
  ''
  # The QT shipped with insync doesn't seem to respect QT_PLUGIN_PATH env var, hence wrapQtApp is moot.
  # Here is a hack to symlink all plugins to insync libs folder.
  + (builtins.concatStringsSep "\n" (builtins.map (pkg: let
      pluginPath = "${pkg.bin or pkg}/${qt5.qtbase.qtPluginPrefix}";
      qmlPath = "${pkg.bin or pkg}/${qt5.qtbase.qtQmlPrefix}";
    in ''
      [ -d ${pluginPath} ] && find -L ${pluginPath} -type f -printf "%P\n" | while read i;do
        mkdir -p $out/lib/insync/PySide2/plugins/$(dirname $i)
        ln -s ${pluginPath}/$i $out/lib/insync/PySide2/plugins/$i
      done
      [ -d ${qmlPath} ] && find -L ${qmlPath} -type f -printf "%P\n" | while read i;do
        mkdir -p $out/lib/insync/PySide2/qml/$(dirname $i)
        ln -s ${qmlPath}/$i $out/lib/insync/PySide2/qml/$i
      done
    '') buildInputs))
  + ''
    # fix the launcher
    rm -f "$out/bin/insync"
    makeWrapper $out/lib/insync/insync $out/bin/insync \
      --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
      --prefix XDG_DATA_DIRS : $out/share

    runHook postInstall
  '';

  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  meta = with lib; {
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    maintainers = with maintainers; [ hellwolf kaesaecracker ];
    homepage = "https://www.insynchq.com";
    description = "Google Drive sync and backup with multiple account support";
    longDescription = ''
     Insync is a commercial application that syncs your Drive files to your
     computer.  It has more advanced features than Google's official client
     such as multiple account support, Google Doc conversion, symlink support,
     and built in sharing.

     There is a 15-day free trial, and it is a paid application after that.
    '';
  };
}
