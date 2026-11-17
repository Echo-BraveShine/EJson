cask "ejson" do
  version "0.1.2"
  sha256 "8ea56562b009664668223250374209f5a1c6b195e9f3bc53b9e275aa0e5d0077"

  url "https://github.com/Echo-BraveShine/EJson/releases/download/v#{version}/EJson-macos.zip"
  name "EJson"
  desc "Desktop JSON editor with a synchronized tree view"
  homepage "https://github.com/Echo-BraveShine/EJson"

  depends_on macos: :monterey

  app "EJson.app"

  uninstall quit: "dev.ekko.ejson"
end
