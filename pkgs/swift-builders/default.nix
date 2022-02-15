{ pkgs }:
with pkgs;
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
in rec {
  TargetType = {
    CLibrary = "CLibrary";
    Library = "Library";
    Executable = "Executable";
  };
  mkDynamicCLibrary = {
    package,
    version,
    src,
    target,
    targetSrcRoot ? "Sources/${target}",
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    targetSrcRoot = "Sources/${target}";
    includeSourceDir = "${targetSrcRoot}/include";
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
        for cFile in $(find ${targetSrcRoot} -name "*.c"); do
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
    package,
    version,
    src,
    target,
    targetSrcRoot ? "Sources/${target}",
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    targetSrcRoot = "Sources/${target}";
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
          $(find ${targetSrcRoot} -name '*.swift') \
          ${depSwiftModules deps}
        '';
    };

  mkExecutable = {
    version,
    src,
    target,
    targetSrcRoot ? "Sources/${target}",
    executableName ? target,
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    targetSrcRoot = "Sources/${target}";
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
          $(find ${targetSrcRoot} -name '*.swift') \
          ${depSwiftModules deps}
        '';
    }
  ;

  mkPackage = {
    name,
    version,
    src,
    targets,
  }:
    let
      buildTarget = attrs: built:
        let
          deps = if attrs?deps then map (d: { name = d; path = built."${d}"; }) attrs.deps else [];
          target = attrs.name;
          patchPhase = if attrs?patchPhase then attrs.patchPhase else "";
          extraCompilerFlags = if attrs?extraCompilerFlags then attrs.extraCompilerFlags else "";
          targetSrcRoot = "Sources/${target}";
        in
          if attrs.type == TargetType.CLibrary then
            mkDynamicCLibrary {
              inherit version src deps target targetSrcRoot patchPhase extraCompilerFlags;
              package = name;
            }
          else if attrs.type == TargetType.Library then
            mkDynamicLibrary {
              inherit version src deps target targetSrcRoot patchPhase extraCompilerFlags;
              package = name;
            }
          else if attrs.type == TargetType.Executable then
            mkExecutable {
              inherit version src deps target targetSrcRoot patchPhase extraCompilerFlags;
            }
          else
            throw "Unknown target type ${attrs.type}"
      ;

      buildTargets = targets: built:
        let
          targetCount = builtins.length targets;
        in
          if targetCount == 0 then
            throw "target list must not be empty"
          else let
            attrs = builtins.head targets;
            newlyBuilt = built // { "${attrs.name}" = (buildTarget attrs built); };
          in
            if targetCount > 1 then
              buildTargets (builtins.tail targets) newlyBuilt
            else
              newlyBuilt
      ;
    in
      symlinkJoin {
        name = "swift-${name}-${version}";
        paths = builtins.attrValues (buildTargets targets {});
      }
  ;
}
