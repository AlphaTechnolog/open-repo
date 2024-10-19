{
  lib,
  stdenv,
  zig_0_13,
  xdg-utils,
  optimize ? "Debug",
  ...
}: let
  zig-hook = zig_0_13.hook.overrideAttrs {
    zig_default_flags = "-Dcpu=baseline -Doptimize=${optimize}";
  };
in stdenv.mkDerivation {
  pname = "open-repo";
  version = "0.1.0";
  src = ../.;

  nativeBuildInputs = [
    zig-hook
  ];

  buildInputs = [
    xdg-utils
  ];

  dontConfigure = true;

  meta = {
    homepage = "https://github.com/AlphaTechnolog/open-repo";
    license = lib.licenses.gpl3;
    platforms = ["x86_64-linux"];
    mainProgram = "open-repo";
  };
}