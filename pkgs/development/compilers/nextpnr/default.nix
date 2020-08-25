{ stdenv, fetchFromGitHub, cmake
, boost, python3, eigen
, icestorm, trellis
, llvmPackages

, enableGui ? true
, wrapQtAppsHook
, qtbase
, OpenGL ? null
}:

let
  boostPython = boost.override { python = python3; enablePython = true; };
in
with stdenv; mkDerivation rec {
  pname = "nextpnr";
  version = "2020.08.22";

  srcs = [
    (fetchFromGitHub {
      owner  = "YosysHQ";
      repo   = "nextpnr";
      rev    = "c8ecb8341ca766e1e7565cc2b652b63eaba67508";
      sha256 = "1cf9ad7w5x452qdc6m9c3in6v9yzip3n1as978lbdh76f5mc00fv";
      name   = "nextpnr";
    })
    (fetchFromGitHub {
      owner  = "YosysHQ";
      repo   = "nextpnr-tests";
      rev    = "8f93e7e0f897b1b5da469919c9a43ba28b623b2a";
      sha256 = "0zpd0w49k9l7rs3wmi2v8z5s4l4lad5rprs5l83w13667himpzyc";
      name   = "nextpnr-tests";
    })
  ];

  sourceRoot = "nextpnr";

  nativeBuildInputs
     = [ cmake ]
    ++ (lib.optional enableGui wrapQtAppsHook);
  buildInputs
     = [ boostPython python3 eigen ]
    ++ (lib.optional enableGui qtbase)
    ++ (lib.optional stdenv.cc.isClang llvmPackages.openmp);

  enableParallelBuilding = true;
  cmakeFlags =
    [ "-DCURRENT_GIT_VERSION=${lib.substring 0 7 (lib.elemAt srcs 0).rev}"
      "-DARCH=generic;ice40;ecp5"
      "-DBUILD_TESTS=ON"
      "-DICEBOX_ROOT=${icestorm}/share/icebox"
      "-DTRELLIS_INSTALL_PREFIX=${trellis}"
      "-DTRELLIS_LIBDIR=${trellis}/lib/trellis"
      "-DUSE_OPENMP=ON"
      # warning: high RAM usage
      "-DSERIALIZE_CHIPDB=OFF"
    ]
    ++ (lib.optional (!enableGui) "-DBUILD_GUI=OFF")
    ++ (lib.optional (enableGui && stdenv.isDarwin)
        "-DOPENGL_INCLUDE_DIR=${OpenGL}/Library/Frameworks");

  patchPhase = with builtins; ''
    # use PyPy for icestorm if enabled
    substituteInPlace ./ice40/family.cmake \
      --replace ''\'''${PYTHON_EXECUTABLE}' '${icestorm.pythonInterp}'
  '';

  preBuild = ''
    ln -s ../nextpnr-tests tests
  '';

  doCheck = true;

  postFixup = lib.optionalString enableGui ''
    wrapQtApp $out/bin/nextpnr-generic
    wrapQtApp $out/bin/nextpnr-ice40
    wrapQtApp $out/bin/nextpnr-ecp5
  '';

  meta = with lib; {
    description = "Place and route tool for FPGAs";
    homepage    = "https://github.com/yosyshq/nextpnr";
    license     = licenses.isc;
    platforms   = platforms.all;
    maintainers = with maintainers; [ thoughtpolice emily ];
  };
}
