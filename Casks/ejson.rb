cask "ejson" do
  version "0.0.9"
  sha256 "514cd67555e58172915296b4c0be0bf2842bc19e8f75f42ad50193abbf71ecfd"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
