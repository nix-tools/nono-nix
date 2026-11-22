{ lib }:
let
  profileDir = ../profiles;
  profileFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".json" name) (
    builtins.readDir profileDir
  );
in
lib.mapAttrs' (
  file: _: lib.nameValuePair (lib.removeSuffix ".json" file) (profileDir + "/${file}")
) profileFiles
