{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "spire";
  version = "1.8.2";

  outputs = [ "out" "agent" "server" ];

  src = fetchFromGitHub {
    owner = "spiffe";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-+xHsNp/Zk+0D1iwGJNjgCvSjepGQEJXWnkWHa6Et9jA=";
  };

  vendorHash = "sha256-mh3LIwUKIyH75AvWX+YgGi5VAU/EzZw5OSpAFIG6ueo=";

  subPackages = [ "cmd/spire-agent" "cmd/spire-server" ];

  # Usually either the agent or server is needed for a given use case, but not both
  postInstall = ''
    mkdir -vp $agent/bin $server/bin
    mv -v $out/bin/spire-agent $agent/bin/
    mv -v $out/bin/spire-server $server/bin/

    ln -vs $agent/bin/spire-agent $out/bin/spire-agent
    ln -vs $server/bin/spire-server $out/bin/spire-server
  '';

  meta = with lib; {
    description = "The SPIFFE Runtime Environment";
    homepage = "https://github.com/spiffe/spire";
    changelog = "https://github.com/spiffe/spire/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ jonringer fkautz ];
  };
}
