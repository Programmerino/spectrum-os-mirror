{ lib, stdenv, fetchFromGitHub, cmake, aws-c-cal, aws-c-common, aws-c-io, aws-checksums, nix, s2n-tls, libexecinfo }:

stdenv.mkDerivation rec {
  pname = "aws-c-event-stream";
  version = "0.2.15";

  src = fetchFromGitHub {
    owner = "awslabs";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-X0ExfVop/YjFmR8TrIejg76MOTMngdUruT7uy0BibrU=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ aws-c-cal aws-c-common aws-c-io aws-checksums s2n-tls ]
    ++ lib.optional stdenv.hostPlatform.isMusl libexecinfo;

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS:BOOL=ON"
  ];

  passthru.tests = {
    inherit nix;
  };

  meta = with lib; {
    description = "C99 implementation of the vnd.amazon.eventstream content-type";
    homepage = "https://github.com/awslabs/aws-c-event-stream";
    license = licenses.asl20;
    platforms = platforms.unix;
    maintainers = with maintainers; [ orivej eelco ];
  };
}
