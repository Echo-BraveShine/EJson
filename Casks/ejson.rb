cask "ejson" do
  version "0.1.1"
  sha256 "531e616c4f27b5bc8fc10f9705b58946691de726067af6fb3e6484fff78eba68"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
