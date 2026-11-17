cask "ejson" do
  version "0.1.4"
  sha256 "d47c393314231922d79663b6f973ec1f011ab7c433c6e0fbaeafd3ba1223f123"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
