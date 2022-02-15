{ pkgs ? import <nixpkgs> { } }:

{
  # The `lib`, `modules`, and `overlay` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  swiftBuilders = pkgs.callPackage ./pkgs/swift-builders { };
  TOMLDecoder = pkgs.callPackage ./pkgs/TOMLDecoder { };
  Yams = pkgs.callPackage ./pkgs/Yams { };
}
