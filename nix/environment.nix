{ pkgs }:
{
  LC_ALL = "C";
  PYTHONDONTWRITEBYTECODE = "1";
  LIBRARY_PATH = "${pkgs.glibc.static}/lib";
}
