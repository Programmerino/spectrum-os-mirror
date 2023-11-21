{ lib, stdenv, fetchFromGitHub, cmake, curl, openssl, Security }:

stdenv.mkDerivation (finalAttrs: {
  pname = "libhv";
  version = "1.3.2";

  src = fetchFromGitHub {
    owner = "ithewei";
    repo = "libhv";
    rev = "v${finalAttrs.version}";
    hash = "sha256-tVuQwj2HvAhp51urGCuNPjBEIaTu9yR031Ih/5or9Pk=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ curl openssl ] ++ lib.optional stdenv.isDarwin Security;

  cmakeFlags = [
    "-DENABLE_UDS=ON"
    "-DWITH_MQTT=ON"
    "-DWITH_CURL=ON"
    "-DWITH_NGHTTP2=ON"
    "-DWITH_OPENSSL=ON"
    "-DWITH_KCP=ON"
  ];

  meta = with lib; {
    description = "A c/c++ network library for developing TCP/UDP/SSL/HTTP/WebSocket/MQTT client/server";
    homepage = "https://github.com/ithewei/libhv";
    license = licenses.bsd3;
    maintainers = with maintainers; [ sikmir ];
    platforms = platforms.unix;
  };
})
