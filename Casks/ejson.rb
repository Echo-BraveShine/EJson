cask "ejson" do
  version "0.0.7"
  sha256 "8624c132ec55d2805dc6772af2358fcdd35b4d39e141819a881e97a31ee6a666"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
