# native desktop client
{ pkgs, meta, sdks, buildCrate }:

let
  lib = pkgs.lib;
in
buildCrate {
  crate = meta.desktop.crate;
  nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];
  buildInputs = with pkgs; [ fontconfig freetype ];

  # winit/glutin dlopen these at runtime
  postInstall = ''
    wrapProgram $out/bin/${meta.desktop.crate} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath sdks.desktopRuntimeLibs}
  '';

  meta.mainProgram = meta.desktop.crate;
}
