{ lib, stdenv, fetchFromGitHub, rakudo, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "zef";
  version = "0.21.0";

  src = fetchFromGitHub {
    owner = "ugexe";
    repo = "zef";
    rev = "v${version}";
    sha256 = "sha256-QVUnn9G28epoUEcK8mwm8S2wDQ/tv5B3Zds7bTUFwlw=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ rakudo ];

  installPhase = ''
    mkdir -p "$out"
    # TODO: Find better solution. zef stores cache stuff in $HOME with the
    # default config.
    env HOME=$TMPDIR ${rakudo}/bin/raku -I. ./bin/zef --/depends --/test-depends --/build-depends --install-to=$out install .
  '';

  postFixup =''
    wrapProgram $out/bin/zef --prefix RAKUDOLIB , "inst#$out"
  '';

  meta = with lib; {
    description = "Raku / Perl6 Module Management";
    homepage    = "https://github.com/ugexe/zef";
    license     = licenses.artistic2;
    platforms   = platforms.unix;
    maintainers = with maintainers; [ sgo ];
  };
}
