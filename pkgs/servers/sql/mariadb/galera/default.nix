{ stdenv, fetchFromGitHub, buildEnv
, asio, boost, check, openssl, scons
}:

let
  galeraLibs = buildEnv {
    name = "galera-lib-inputs-united";
    paths = [ openssl.out boost check ];
  };

in stdenv.mkDerivation rec {
  pname = "mariadb-galera";
  version = "26.4.5";

  src = fetchFromGitHub {
    owner = "codership";
    repo = "galera";
    rev = "release_${version}";
    sha256 = "10sir0hxxglw9jsjrclfgrqm8n5zng6rwj2fgff141x9n9l55w7l";
    fetchSubmodules = true;
  };

  buildInputs = [ asio boost check openssl scons ];

  postPatch = ''
    substituteInPlace SConstruct \
      --replace "boost_library_path = '''" "boost_library_path = '${boost}/lib'"
  '';

  preConfigure = ''
    export CPPFLAGS="-I${asio}/include -I${boost.dev}/include -I${check}/include -I${openssl.dev}/include"
    export LIBPATH="${galeraLibs}/lib"
  '';

  sconsFlags = "ssl=1 system_asio=1 strict_build_flags=0";

  enableParallelBuilding = true;

  installPhase = ''
    # copied with modifications from scripts/packages/freebsd.sh
    GALERA_LICENSE_DIR="$share/licenses/${pname}-${version}"
    install -d $out/{bin,lib/galera,share/doc/galera,$GALERA_LICENSE_DIR}
    install -m 555 "garb/garbd"                       "$out/bin/garbd"
    install -m 444 "libgalera_smm.so"                 "$out/lib/galera/libgalera_smm.so"
    install -m 444 "scripts/packages/README"          "$out/share/doc/galera/"
    install -m 444 "scripts/packages/README-MySQL"    "$out/share/doc/galera/"
    install -m 444 "scripts/packages/freebsd/LICENSE" "$out/$GALERA_LICENSE_DIR"
    install -m 444 "LICENSE"                          "$out/$GALERA_LICENSE_DIR/GPLv2"
    install -m 444 "asio/LICENSE_1_0.txt"             "$out/$GALERA_LICENSE_DIR/LICENSE.asio"
    install -m 444 "www.evanjones.ca/LICENSE"         "$out/$GALERA_LICENSE_DIR/LICENSE.crc32c"
  '';

  meta = with stdenv.lib; {
    description = "Galera 3 wsrep provider library";
    homepage = "https://galeracluster.com/";
    license = licenses.lgpl2;
    maintainers = with maintainers; [ izorkin ];
    platforms = platforms.all;
  };
}
