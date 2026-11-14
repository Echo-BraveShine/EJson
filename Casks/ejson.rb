cask "ejson" do
  version "0.0.6"
  sha256 "29b330e89c0dea946d18285022b626d42b6a67a6aa9df065a49137e5d94e049d"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
