{ lib, buildEnv, runCommand, writeText, makeWrapper, libfaketime, makeFontsConf
, perl, bash, coreutils, gnused, gnugrep, gawk, ghostscript
, bin, tl }:
# combine =
args@{
  pkgFilter ? (pkg: pkg.tlType == "run" || pkg.tlType == "bin" || pkg.pname == "core"
                    || pkg.hasManpages or false)
, extraName ? "combined"
, extraVersion ? ""
, ...
}:
let
  # combine a set of TL packages into a single TL meta-package
  combinePkgs = pkgList: lib.catAttrs "pkg" (
    let
      # a TeX package is an attribute set { pkgs = [ ... ]; ... } where pkgs is a list of derivations
      # the derivations make up the TeX package and optionally (for backward compatibility) its dependencies
      tlPkgToSets = { pkgs, ... }: map ({ tlType, version ? "", outputName ? "", ... }@pkg: {
          # outputName required to distinguish among bin.core-big outputs
          key = "${pkg.pname or pkg.name}.${tlType}-${version}-${outputName}";
          inherit pkg;
        }) pkgs;
      pkgListToSets = lib.concatMap tlPkgToSets; in
    builtins.genericClosure {
      startSet = pkgListToSets pkgList;
      operator = { pkg, ... }: pkgListToSets (pkg.tlDeps or []);
    });

  pkgSet = removeAttrs args [ "pkgFilter" "extraName" "extraVersion" ];
  pkgList = rec {
    combined = combinePkgs (lib.attrValues pkgSet);
    all = lib.filter pkgFilter combined;
    splitBin = builtins.partition (p: p.tlType == "bin") all;
    bin = splitBin.right;
    nonbin = splitBin.wrong;
    tlpkg = lib.filter (pkg: pkg.tlType == "tlpkg") combined;
  };
  # list generated by inspecting `grep -IR '\([^a-zA-Z]\|^\)gs\( \|$\|"\)' "$TEXMFDIST"/scripts`
  # and `grep -IR rungs "$TEXMFDIST"`
  # and ignoring luatex, perl, and shell scripts (those must be patched using postFixup)
  needsGhostscript = lib.any (p: lib.elem p.pname [ "context" "dvipdfmx" "latex-papersize" "lyluatex" ]) pkgList.bin;

  name = "texlive-${extraName}-${bin.texliveYear}${extraVersion}";

  texmfdist = (buildEnv {
    name = "${name}-texmfdist";

    # remove fake derivations (without 'outPath') to avoid undesired build dependencies
    paths = lib.catAttrs "outPath" pkgList.nonbin;

    # mktexlsr
    nativeBuildInputs = [ (lib.last tl."texlive.infra".pkgs) ];

    postBuild = # generate ls-R database
    ''
      mktexlsr "$out"
    '';
  }).overrideAttrs (_: { allowSubstitutes = true; });

  tlpkg = (buildEnv {
    name = "${name}-tlpkg";

    # remove fake derivations (without 'outPath') to avoid undesired build dependencies
    paths = lib.catAttrs "outPath" pkgList.tlpkg;
  }).overrideAttrs (_: { allowSubstitutes = true; });

  # the 'non-relocated' packages must live in $TEXMFROOT/texmf-dist
  # and sometimes look into $TEXMFROOT/tlpkg (notably fmtutil, updmap look for perl modules in both)
  texmfroot = runCommand "${name}-texmfroot" {
    inherit texmfdist tlpkg;
  } ''
    mkdir -p "$out"
    ln -s "$texmfdist" "$out"/texmf-dist
    ln -s "$tlpkg" "$out"/tlpkg
  '';

  # expose info and man pages in usual /share/{info,man} location
  doc = buildEnv {
    name = "${name}-doc";

    paths = [ (texmfdist.outPath + "/doc") ];
    extraPrefix = "/share";

    pathsToLink = [
      "/info"
      "/man"
    ];
  };

in (buildEnv {

  inherit name;

  ignoreCollisions = false;

  # remove fake derivations (without 'outPath') to avoid undesired build dependencies
  paths = lib.catAttrs "outPath" pkgList.bin ++ [ doc ];
  pathsToLink = [
    "/"
    "/share/texmf-var/scripts"
    "/share/texmf-var/tex/generic/config"
    "/share/texmf-var/web2c"
    "/share/texmf-config"
    "/bin" # ensure these are writeable directories
  ];

  nativeBuildInputs = [
    makeWrapper
    libfaketime
    (lib.last tl."texlive.infra".pkgs) # mktexlsr
    (lib.last tl.texlive-scripts.pkgs) # fmtutil, updmap
    (lib.last tl.texlive-scripts-extra.pkgs) # texlinks
    perl
  ];

  passthru = {
    # This is set primarily to help find-tarballs.nix to do its job
    packages = pkgList.all;
    # useful for inclusion in the `fonts.packages` nixos option or for use in devshells
    fonts = "${texmfroot}/texmf-dist/fonts";
  };

  postBuild =
    # environment variables (note: only export the ones that are used in the wrappers)
  ''
    TEXMFROOT="${texmfroot}"
    TEXMFDIST="${texmfdist}"
    export PATH="$out/bin:$PATH"
    TEXMFSYSCONFIG="$out/share/texmf-config"
    TEXMFSYSVAR="$out/share/texmf-var"
    export TEXMFCNF="$TEXMFSYSVAR/web2c"
  '' +
    # wrap executables with required env vars as early as possible
    # 1. we want texlive.combine to use the wrapped binaries, to catch bugs
    # 2. we do not want to wrap links generated by texlinks
  ''
    enable -f '${bash}/lib/bash/realpath' realpath
    declare -i wrapCount=0
    for link in "$out"/bin/*; do
      target="$(realpath "$link")"
      if [[ "''${target##*/}" != "''${link##*/}" ]] ; then
        # detected alias with different basename, use immediate target of $link to preserve $0
        # relevant for mktexfmt, repstopdf, ...
        target="$(readlink "$link")"
      fi

      rm "$link"
      makeWrapper "$target" "$link" \
        --inherit-argv0 \
        --prefix PATH : "${
          # very common dependencies that are not detected by tests.texlive.binaries
          lib.makeBinPath ([ coreutils gawk gnugrep gnused ] ++ lib.optional needsGhostscript ghostscript)}:$out/bin" \
        --set-default TEXMFCNF "$TEXMFCNF" \
        --set-default FONTCONFIG_FILE "${
          # necessary for XeTeX to find the fonts distributed with texlive
          makeFontsConf { fontDirectories = [ "${texmfroot}/texmf-dist/fonts" ]; }
        }"
      wrapCount=$((wrapCount + 1))
    done
    echo "wrapped $wrapCount binaries and scripts"
  '' +
    # patch texmf-dist  -> $TEXMFDIST
    # patch texmf-local -> $out/share/texmf-local
    # patch texmf.cnf   -> $TEXMFSYSVAR/web2c/texmf.cnf
    # TODO: perhaps do lua actions?
    # tried inspiration from install-tl, sub do_texmf_cnf
  ''
    mkdir -p "$TEXMFCNF"
    if [ -e "$TEXMFDIST/web2c/texmfcnf.lua" ]; then
      sed \
        -e "s,\(TEXMFOS[ ]*=[ ]*\)[^\,]*,\1\"$TEXMFROOT\",g" \
        -e "s,\(TEXMFDIST[ ]*=[ ]*\)[^\,]*,\1\"$TEXMFDIST\",g" \
        -e "s,\(TEXMFSYSVAR[ ]*=[ ]*\)[^\,]*,\1\"$TEXMFSYSVAR\",g" \
        -e "s,\(TEXMFSYSCONFIG[ ]*=[ ]*\)[^\,]*,\1\"$TEXMFSYSCONFIG\",g" \
        -e "s,\(TEXMFLOCAL[ ]*=[ ]*\)[^\,]*,\1\"$out/share/texmf-local\",g" \
        -e "s,\$SELFAUTOLOC,$out,g" \
        -e "s,selfautodir:/,$out/share/,g" \
        -e "s,selfautodir:,$out/share/,g" \
        -e "s,selfautoparent:/,$out/share/,g" \
        -e "s,selfautoparent:,$out/share/,g" \
        "$TEXMFDIST/web2c/texmfcnf.lua" > "$TEXMFCNF/texmfcnf.lua"
    fi

    sed \
      -e "s,\(TEXMFROOT[ ]*=[ ]*\)[^\,]*,\1$TEXMFROOT,g" \
      -e "s,\(TEXMFDIST[ ]*=[ ]*\)[^\,]*,\1$TEXMFDIST,g" \
      -e "s,\(TEXMFSYSVAR[ ]*=[ ]*\)[^\,]*,\1$TEXMFSYSVAR,g" \
      -e "s,\(TEXMFSYSCONFIG[ ]*=[ ]*\)[^\,]*,\1$TEXMFSYSCONFIG,g" \
      -e "s,\$SELFAUTOLOC,$out,g" \
      -e "s,\$SELFAUTODIR,$out/share,g" \
      -e "s,\$SELFAUTOPARENT,$out/share,g" \
      -e "s,\$SELFAUTOGRANDPARENT,$out/share,g" \
      -e "/^mpost,/d" `# CVE-2016-10243` \
      "$TEXMFDIST/web2c/texmf.cnf" > "$TEXMFCNF/texmf.cnf"
  '' +
    # now filter hyphenation patterns and formats
  (let
    hyphens = lib.filter (p: p.hasHyphens or false && p.tlType == "run") pkgList.splitBin.wrong;
    hyphenPNames = map (p: p.pname) hyphens;
    formats = lib.filter (p: p ? formats && p.tlType == "run") pkgList.splitBin.wrong;
    formatPNames = map (p: p.pname) formats;
    # sed expression that prints the lines in /start/,/end/ except for /end/
    section = start: end: "/${start}/,/${end}/{ /${start}/p; /${end}/!p; };\n";
    script =
      writeText "hyphens.sed" (
        # document how the file was generated (for language.dat)
        "1{ s/^(% Generated by .*)$/\\1, modified by texlive.combine/; p; }\n"
        # pick up the header
        + "2,/^% from/{ /^% from/!p; };\n"
        # pick up all sections matching packages that we combine
        + lib.concatMapStrings (pname: section "^% from ${pname}:$" "^% from|^%%% No changes may be made beyond this point.$") hyphenPNames
        # pick up the footer (for language.def)
        + "/^%%% No changes may be made beyond this point.$/,$p;\n"
      );
    scriptLua =
      writeText "hyphens.lua.sed" (
        "1{ s/^(-- Generated by .*)$/\\1, modified by texlive.combine/; p; }\n"
        + "2,/^-- END of language.us.lua/p;\n"
        + lib.concatMapStrings (pname: section "^-- from ${pname}:$" "^}$|^-- from") hyphenPNames
        + "$p;\n"
      );
    # formats not being installed must be disabled by prepending #! (see man fmtutil)
    # sed expression that enables the formats in /start/,/end/
    enableFormats = pname: "/^# from ${pname}:$/,/^# from/{ s/^#! //; };\n";
    fmtutilSed =
      writeText "fmtutil.sed" (
        # document how file was generated
        "1{ s/^(# Generated by .*)$/\\1, modified by texlive.combine/; }\n"
        # disable all formats, even those already disabled
        + "s/^([^#]|#! )/#! \\1/;\n"
        # enable the formats from the packages being installed
        + lib.concatMapStrings enableFormats formatPNames
        # clean up formats that have been disabled twice
        + "s/^#! #! /#! /;\n"
      );
  in ''
    mkdir -p "$TEXMFSYSVAR/tex/generic/config"
    for fname in tex/generic/config/language.{dat,def}; do
      [[ -e "$TEXMFDIST/$fname" ]] && sed -E -n -f '${script}' "$TEXMFDIST/$fname" > "$TEXMFSYSVAR/$fname"
    done
    [[ -e "$TEXMFDIST"/tex/generic/config/language.dat.lua ]] && sed -E -n -f '${scriptLua}' \
      "$TEXMFDIST"/tex/generic/config/language.dat.lua > "$TEXMFSYSVAR"/tex/generic/config/language.dat.lua
    [[ -e "$TEXMFDIST"/web2c/fmtutil.cnf ]] && sed -E -f '${fmtutilSed}' "$TEXMFDIST"/web2c/fmtutil.cnf > "$TEXMFCNF"/fmtutil.cnf

    # create $TEXMFSYSCONFIG database, make new $TEXMFSYSVAR files visible to kpathsea
    mktexlsr "$TEXMFSYSCONFIG" "$TEXMFSYSVAR"
  '') +
    # generate format links (reads fmtutil.cnf to know which ones) *after* the wrappers have been generated
  ''
    texlinks --quiet "$out/bin"
  '' +
  # texlive postactions (see TeXLive::TLUtils::_do_postaction_script)
  (lib.concatMapStrings (pkg: ''
    postaction='${pkg.postactionScript}'
    case "$postaction" in
      *.pl) postInterp=perl ;;
      *.texlua) postInterp=texlua ;;
      *) postInterp= ;;
    esac
    echo "postaction install script for ${pkg.pname}: ''${postInterp:+$postInterp }$postaction install $TEXMFROOT"
    $postInterp "$TEXMFROOT/$postaction" install "$TEXMFROOT"
  '') (lib.filter (pkg: pkg ? postactionScript) pkgList.tlpkg)) +
    # generate formats
  ''
    # many formats still ignore SOURCE_DATE_EPOCH even when FORCE_SOURCE_DATE=1
    # libfaketime fixes non-determinism related to timestamps ignoring FORCE_SOURCE_DATE
    # we cannot fix further randomness caused by luatex; for further details, see
    # https://salsa.debian.org/live-team/live-build/-/blob/master/examples/hooks/reproducible/2006-reproducible-texlive-binaries-fmt-files.hook.chroot#L52
    # note that calling faketime and fmtutil is fragile (faketime uses LD_PRELOAD, fmtutil calls /bin/sh, causing potential glibc issues on non-NixOS)
    # so we patch fmtutil to use faketime, rather than calling faketime fmtutil
    substitute "$TEXMFDIST"/scripts/texlive/fmtutil.pl fmtutil \
      --replace 'my $cmdline = "$eng -ini ' 'my $cmdline = "faketime -f '"'"'\@1980-01-01 00:00:00 x0.001'"'"' $eng -ini '
    FORCE_SOURCE_DATE=1 TZ= perl fmtutil --sys --all | grep '^fmtutil' # too verbose

    # Disable unavailable map files
    echo y | updmap --sys --syncwithtrees --force 2>&1 | grep '^\(updmap\|  /\)'
    # Regenerate the map files (this is optional)
    updmap --sys --force 2>&1 | grep '^\(updmap\|  /\)'

    # sort entries to improve reproducibility
    [[ -f "$TEXMFSYSCONFIG"/web2c/updmap.cfg ]] && sort -o "$TEXMFSYSCONFIG"/web2c/updmap.cfg "$TEXMFSYSCONFIG"/web2c/updmap.cfg

    mktexlsr "$TEXMFSYSCONFIG" "$TEXMFSYSVAR" # to make sure (of what?)
  '' +
    # remove *-sys scripts since /nix/store is readonly
  ''
    rm "$out"/bin/*-sys
  '' +
  # TODO: a context trigger https://www.preining.info/blog/2015/06/debian-tex-live-2015-the-new-layout/
    # http://wiki.contextgarden.net/ConTeXt_Standalone#Unix-like_platforms_.28Linux.2FMacOS_X.2FFreeBSD.2FSolaris.29

  # MkIV uses its own lookup mechanism and we need to initialize
  # caches for it.
  # We use faketime to fix the embedded timestamps and patch the uuids
  # with some random but constant values.
  ''
    if [[ -e "$out/bin/mtxrun" ]]; then
      substitute "$TEXMFDIST"/scripts/context/lua/mtxrun.lua mtxrun.lua \
        --replace 'cache_uuid=osuuid()' 'cache_uuid="e2402e51-133d-4c73-a278-006ea4ed734f"' \
        --replace 'uuid=osuuid(),' 'uuid="242be807-d17e-4792-8e39-aa93326fc871",'
      FORCE_SOURCE_DATE=1 TZ= faketime -f '@1980-01-01 00:00:00 x0.001' luatex --luaonly mtxrun.lua --generate
    fi
  '' +
  # Get rid of all log files. They are not needed, but take up space
  # and render the build unreproducible by their embedded timestamps
  # and other non-deterministic diagnostics.
  ''
    find "$TEXMFSYSVAR"/web2c -name '*.log' -delete
  '' +
  # link TEXMFDIST in $out/share for backward compatibility
  ''
    ln -s "$TEXMFDIST" "$out"/share/texmf
  ''
  ;
}).overrideAttrs (_: { allowSubstitutes = true; })
