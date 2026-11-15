cask "ejson" do
  version "0.0.8"
  sha256 "df1f4b475e85080702241ee5753056bc4a25e35f5fd53c3367cc3ff0be5f8170"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
