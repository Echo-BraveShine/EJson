cask "ejson" do
  version "0.1.3"
  sha256 "cf7b37e62456931bd198bfd51e0542c46482ccc1e1f2d05975ae79b2d649771e"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
