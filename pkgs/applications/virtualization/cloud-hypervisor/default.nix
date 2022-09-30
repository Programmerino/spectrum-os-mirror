{ lib, stdenv, fetchFromGitHub, fetchCrate, rustPlatform, pkg-config
, dtc, openssl
}:

rustPlatform.buildRustPackage rec {
  pname = "cloud-hypervisor";
  version = "32.0";

  src = fetchFromGitHub {
    owner = "cloud-hypervisor";
    repo = pname;
    rev = "v${version}";
    sha256 = "aSBzbxL9TOYVQUZBgHI8GHELfx9avRDHh/MWmN+/nY0=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "acpi_tables-0.1.0" = "sha256-aT0p85QDGjBEnbABedm0q7JPpiNjhupoIzBWifQ0RaQ=";
      "kvm-bindings-0.6.0" = "sha256-wGdAuPwsgRIqx9dh0m+hC9A/Akz9qg9BM+p06Fi5ACM=";
      "kvm-ioctls-0.13.0" = "sha256-jHnFGwBWnAa2lRu4a5eRNy1Y26NX5MV8alJ86VR++QE=";
      "micro_http-0.1.0" = "sha256-w2witqKXE60P01oQleujmHSnzMKxynUGKWyq5GEh1Ew=";
      "mshv-bindings-0.1.1" = "sha256-Pg7UPhW6UOahCQu1jU27lenrsmLT/VdceDqL6lOdmFU=";
      "versionize_derive-0.1.4" = "sha256-BPl294UqjVl8tThuvylXUFjFNjJx8OSfBGJLg8jIkWw=";
      "vfio-bindings-0.4.0" = "sha256-lKdoo/bmnZTRV7RRWugwHDFFCB6FKxpzxDEEMVqSbwA=";
      "vfio_user-0.1.0" = "sha256-JYNiONQNNpLu57Pjdn2BlWOdmSf3c4/XJg/RsVxH3uk=";
      "vm-fdt-0.2.0" = "sha256-gVKGiE3ZSe+z3oOHR3zqVdc7XMHzkp4kO4p/WfK0VI8=";
    };
  };

  separateDebugInfo = true;

  vhost = fetchCrate {
    pname = "vhost";
    version = "0.6.0";
    sha256 = "cbB1MVYIqOY2voiZt8jsGMAt54oU62cDdJq2mtj/1BA=";
  };

  postUnpack = ''
    mkdir -p vhost/crates
    pushd vhost/crates
    unpackFile ${vhost}
    mv * vhost
    chmod -R +w vhost
    popd
  '';

  cargoPatches = [
    ./0001-build-use-local-vhost.patch
    ./0002-virtio-devices-add-a-GPU-device.patch
  ];

  vhostPatches = [
    vhost/0001-vhost_user-add-shared-memory-region-support.patch
    vhost/0002-devices-vhost-user-add-protocol-flag-for-shmem.patch
  ];

  postPatch = ''
    pushd ../vhost/crates/vhost
    for patch in $vhostPatches; do
        echo applying patch $patch
        patch -p1 < $patch
    done
    popd
  '';

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ] ++ lib.optional stdenv.isAarch64 dtc;

  OPENSSL_NO_VENDOR = true;

  # Integration tests require root.
  cargoTestFlags = [ "--bins" ];

  meta = with lib; {
    homepage = "https://github.com/cloud-hypervisor/cloud-hypervisor";
    description = "Open source Virtual Machine Monitor (VMM) that runs on top of KVM";
    changelog = "https://github.com/cloud-hypervisor/cloud-hypervisor/releases/tag/v${version}";
    license = with licenses; [ asl20 bsd3 ];
    maintainers = with maintainers; [ offline qyliss ];
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
}
