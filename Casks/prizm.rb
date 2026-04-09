cask "prizm" do
  version "1.1.0"
  sha256 "600d35c4c26699086866642f16a04e64279c5cb4cae7cdc652480e88ddd14380"

  url "https://github.com/b0x42/prizm/releases/download/v#{version}/Prizm-v#{version}.dmg"
  name "Prizm"
  desc "Native macOS client for Vaultwarden and self-hosted Bitwarden"
  homepage "https://github.com/b0x42/prizm"

  depends_on macos: ">= :tahoe"

  app "Prizm.app"
end
