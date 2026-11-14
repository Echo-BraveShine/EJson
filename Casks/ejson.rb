cask "ejson" do
  version "0.0.5"
  sha256 "cf72342388df87a1a442702fee7394b3d1a0cdb5b07ae670db72114ddbce56de"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
