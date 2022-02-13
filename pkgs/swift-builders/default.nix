{ stdenv, swift }:
let
  depFlags = deps: builtins.concatStringsSep " " (map
    (dep: "-Xlinker -rpath -Xlinker ${dep.path}/lib -L ${dep.path}/lib -I ${dep.path}/swift")
    deps);
  depSwiftModules = deps: builtins.concatStringsSep " " (map
    (dep: "${dep.path}/swift/${dep.name}.swiftmodule")
    deps);
  buildInputs = [ swift ];
  phases = [ "unpackPhase" "patchPhase"  "buildPhase" "installPhase" ];
  buildDir = "tmp";
  installPhase = ''
    mv ${buildDir} $out
  '';
in {
  mkDynamicLibrary = {
    src,
    package,
    version,
    target ? package,
    deps ? [],
    patchPhase ? "",
    extraSwiftcFlags ? "",
  }:
  let
    sourceDir = "Sources/${target}";
    swiftDir = "${buildDir}/swift";
    libDir = "${buildDir}/lib";
    libName = "lib${target}.so";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "swift-${package}-${target}";
      buildPhase = ''
        mkdir ${buildDir}
        mkdir ${swiftDir}
        mkdir ${libDir}
        swiftc \
          -emit-library \
          -module-name ${target} \
          -module-link-name ${target} \
          -emit-module \
          -emit-module-path "${swiftDir}/${target}.swiftmodule" \
          -emit-dependencies \
          -DSWIFT_PACKAGE \
          -O \
          -enable-testing \
          -Xlinker -soname -Xlinker ${libName} \
          -Xlinker -rpath -Xlinker ${libDir} \
          ${depFlags deps} \
          -o ${libDir}/${libName} \
          $(find ${sourceDir} -name '*.swift') \
          ${depSwiftModules deps}
        '';
    };

  mkExecutable = {
    src,
    version,
    target,
    executableName ? target,
    deps ? [],
    patchPhase ? "",
  }:
  let
    sourceDir = "Sources/${target}";
    binDir = "${buildDir}/bin";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "${executableName}";
      buildPhase = ''
        mkdir ${buildDir}
        mkdir ${binDir}
        swiftc \
          -emit-executable \
          ${depFlags deps} \
          -o ${binDir}/${executableName} \
          $(find ${sourceDir} -name '*.swift') \
          ${depSwiftModules deps}
        '';
    };
}
