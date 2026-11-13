cask "ejson" do
  version "0.0.4"
  sha256 "041d4128485549a5e4a6c3d9fda46b8908e3413f7c1643fa08b34673d5abda7c"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
