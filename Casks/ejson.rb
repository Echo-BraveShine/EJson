cask "ejson" do
  version "0.0.3"
  sha256 "7da716bacea15c9adeff62f8c34f316453200e1c0a78afd1d2153f84d93bc95e"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
