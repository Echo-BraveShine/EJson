cask "ejson" do
  version "0.0.2"
  sha256 "eb675b741496ab34c0a4078907233d3cc3f6fc6a3cfad3a374925ec8b6f3b1e0"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
