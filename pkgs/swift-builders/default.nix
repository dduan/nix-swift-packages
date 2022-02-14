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
  buildDir = "build";
  installPhase = ''
    mv ${buildDir} $out
  '';
in {
  mkDynamicCLibrary = {
    src,
    package,
    version,
    target ? package,
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    sourceDir = "Sources/${target}";
    includeSourceDir = "${sourceDir}/include";
    includeDir = "${buildDir}/swift";
    libDir = "${buildDir}/lib";
    binDir = "tmp";
    libName = "lib${target}.so";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "swift-${package}-${target}-${version}";
      buildPhase = ''
        mkdir ${buildDir}
        mkdir ${libDir}
        mkdir ${binDir}
        for cFile in $(find ${sourceDir} -name "*.c"); do
          clang \
            -I${includeSourceDir} \
            -O3 \
            -DNDEBUG \
            -fPIC \
            -MD \
            -MT ${binDir}/$(basename $cFile).o \
            -MF ${binDir}/$(basename $cFile).o.d \
            -o ${binDir}/$(basename $cFile).o \
            -c $cFile \
            ${extraCompilerFlags}
        done

        cp -r ${includeSourceDir} ${includeDir}

        clang \
          -fPIC \
          -O3 \
          -DNDEBUG \
          -shared \
          -Wl,-soname,${libName} \
          -o ${libDir}/${libName} \
          ${binDir}/*.o \
          ${extraCompilerFlags}
      '';
    };

  mkDynamicLibrary = {
    src,
    package,
    version,
    target ? package,
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    sourceDir = "Sources/${target}";
    includeDir = "${buildDir}/swift";
    libDir = "${buildDir}/lib";
    libName = "lib${target}.so";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "swift-${package}-${target}-${version}";
      buildPhase = ''
        mkdir ${buildDir}
        mkdir ${includeDir}
        mkdir ${libDir}
        swiftc \
          -emit-library \
          -module-name ${target} \
          -module-link-name ${target} \
          -emit-module \
          -emit-module-path "${includeDir}/${target}.swiftmodule" \
          -emit-dependencies \
          -DSWIFT_PACKAGE \
          -O \
          -enable-testing \
          -Xlinker -soname -Xlinker ${libName} \
          -Xlinker -rpath -Xlinker ${libDir} \
          ${depFlags deps} \
          -o ${libDir}/${libName} \
          ${extraCompilerFlags} \
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
    extraCompilerFlags ? "",
  }:
  let
    sourceDir = "Sources/${target}";
    binDir = "${buildDir}/bin";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "${executableName}-${version}";
      buildPhase = ''
        mkdir ${buildDir}
        mkdir ${binDir}
        swiftc \
          -emit-executable \
          ${depFlags deps} \
          -o ${binDir}/${executableName} \
          ${extraCompilerFlags} \
          $(find ${sourceDir} -name '*.swift') \
          ${depSwiftModules deps}
        '';
    };
}
