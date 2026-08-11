{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:
pkgs.mkShell {
  buildInputs = [
    pkgs.python312
    pkgs.python312Packages.pip
    pkgs.python312Packages.virtualenv
    pkgs.cudaPackages.cudatoolkit
    pkgs.stdenv.cc.cc.lib
    pkgs.sox
  ];
  shellHook = ''
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.cudaPackages.cudatoolkit}/lib:$LD_LIBRARY_PATH
    export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
  '';
}
