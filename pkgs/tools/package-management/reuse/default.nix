{ lib, python3Packages, fetchFromGitHub }:

with python3Packages;

buildPythonApplication rec {
  pname = "reuse";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "fsfe";
    repo = "reuse-tool";
    rev = "v${version}";
    sha256 = "0wkk107s0bpvbknapns0qdzf8csrzc2j6gliy6pa8z208fcfzyy3";
  };

  propagatedBuildInputs = [
    binaryornot
    boolean-py
    debian
    jinja2
    license-expression
    requests
    setuptools
    setuptools_scm
  ];

  checkInputs = [ pytest ];

  meta = with lib; {
    description = "A tool for compliance with the REUSE Initiative recommendations";
    homepage = "https://github.com/fsfe/reuse-tool";
    license = with licenses; [ asl20 cc-by-sa-40 cc0 gpl3Plus ];
    maintainers = [ maintainers.FlorianFranzen ];
  };
}
