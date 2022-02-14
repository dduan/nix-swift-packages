{ pkgs ? import <nixpkgs> {}}:
with pkgs;
let
  version = "4.0.6";
  builders = import ../swift-builders { inherit stdenv swift; };
  package = "Yams";
  src = fetchFromGitHub {
    owner = "jpsim";
    repo = "Yams";
    rev = "${version}";
    sha256 = "sha256-haysR6hdPF9MWZ0U8KIn3wC3PptvFhVijUroqEfwI6E=";
  };
in
  let
    CYaml = rec {
      name = "CYaml";
      path = builders.mkDynamicCLibrary {
        inherit src version package;
        target = name;
      };
    };
    Yams = rec {
      name = "Yams";
      path = builders.mkDynamicLibrary {
        inherit src version package;
        target = name;
        deps = [ CYaml ];
      };
    };
  in
    symlinkJoin {
      name = "swift-${package}-${version}";
      paths = [ CYaml.path Yams.path ];
    }
