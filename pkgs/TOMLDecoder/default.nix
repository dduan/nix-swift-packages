{ stdenv, fetchFromGitHub, symlinkJoin, swift }:
{ version }:
let
  builders = import ../swift-builders { inherit stdenv swift; };
  package = "TOMLDecoder";
  src = fetchFromGitHub {
    owner = "dduan";
    repo = "TOMLDecoder";
    rev = "${version}";
    sha256 = "sha256-Vk1ALdwjgV/fsep2NwEOYj+rSByeMXj58vf89dGjFK4=";
  };
in
  let
    Deserializer = rec {
      name = "Deserializer";
      path = builders.mkDynamicLibrary {
        inherit src version package;
        target = "${name}";
      };
    };

    TOMLDecoder = rec {
      name = "TOMLDecoder";
      path = builders.mkDynamicLibrary {
        inherit src version package;
        target = "${name}";
        deps = [ Deserializer ];
      };
    };
  in
    symlinkJoin {
      name = "swift-${package}-${version}";
      paths = [ Deserializer.path TOMLDecoder.path ];
    }
