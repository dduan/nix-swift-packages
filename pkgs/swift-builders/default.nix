{ pkgs }:
with pkgs;
let
  depFlags = deps: builtins.concatStringsSep " " (map
    (dep: "-Xlinker -rpath -Xlinker ${dep.path}/lib -L ${dep.path}/lib -I ${dep.path}/swift -Xcc -I${dep.path}/swift")
    deps);
  depSwiftModules = deps: builtins.concatStringsSep " " (map
    (dep: "${dep.path}/swift/${dep.name}.swiftmodule")
    deps);
  depLibs = deps: builtins.concatStringsSep " " (map (d: "${d.path}/lib/lib${d.name}.so") deps);
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
    srcRoot ? "Sources/${target}",
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    includeSourceDir = "${srcRoot}/include";
    includeDir = "${buildDir}/swift";
    libDir = "${buildDir}/lib";
    libName = "lib${target}.so";
    tmpDir = "tmp";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "swift-${package}-${target}";
      buildPhase = ''
        mkdir ${buildDir}
        mkdir ${libDir}
        mkdir ${tmpDir}
        for cFile in $(find ${srcRoot} -name "*.c"); do
          clang \
            -I${includeSourceDir} \
            -O3 \
            -DNDEBUG \
            -fPIC \
            -MD \
            -MT ${tmpDir}/$(basename $cFile).o \
            -MF ${tmpDir}/$(basename $cFile).o.d \
            -o ${tmpDir}/$(basename $cFile).o \
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
          ${tmpDir}/*.o \
          ${extraCompilerFlags} \
          ${depLibs deps}
      '';
    };

  mkDynamicLibrary = {
    package,
    version,
    src,
    target,
    srcRoot ? "Sources/${target}",
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
    includeDir = "${buildDir}/swift";
    libDir = "${buildDir}/lib";
    libName = "lib${target}.so";
  in
    stdenv.mkDerivation rec {
      inherit src version patchPhase buildInputs phases installPhase;
      pname = "swift-${package}-${target}";
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
          $(find ${srcRoot} -name '*.swift') \
          ${depSwiftModules deps} \
          ${depLibs deps}
        '';
    };

  mkExecutable = {
    version,
    src,
    target,
    srcRoot ? "Sources/${target}",
    executableName ? target,
    deps ? [],
    patchPhase ? "",
    extraCompilerFlags ? "",
  }:
  let
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
          ${extraCompilerFlags} \
          $(find ${srcRoot} -name '*.swift') \
          ${depSwiftModules deps} \
          ${depLibs deps}
        '';
    }
  ;

  mkPackage = {
    name,
    version,
    src,
    dependencies ? {},
    targets,
  }:
    let
      buildTarget = attrs: built:
        let
          deps = if attrs?deps then map (d: { name = d; path = built."${d}"; }) attrs.deps else [];
          target = attrs.name;
          patchPhase = if attrs?patchPhase then attrs.patchPhase else "";
          extraCompilerFlags = if attrs?extraCompilerFlags then attrs.extraCompilerFlags else "";
          srcRoot = if attrs?srcRoot then attrs.srcRoot else "Sources/${target}";
        in
          if attrs.type == TargetType.CLibrary then
            mkDynamicCLibrary {
              inherit version src deps target srcRoot patchPhase extraCompilerFlags;
              package = name;
            }
          else if attrs.type == TargetType.Library then
            mkDynamicLibrary {
              inherit version src deps target srcRoot patchPhase extraCompilerFlags;
              package = name;
            }
          else if attrs.type == TargetType.Executable then
            mkExecutable {
              inherit version src deps target srcRoot patchPhase extraCompilerFlags;
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
        paths = builtins.attrValues (buildTargets targets dependencies);
      }
  ;
}
