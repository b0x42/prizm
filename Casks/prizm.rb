cask "prizm" do
  version "1.4.2"
  sha256 :no_check

  url "https://github.com/b0x42/prizm/releases/download/v#{version}/Prizm-v#{version}.dmg"
  name "Prizm"
  desc "Native macOS client for Vaultwarden and self-hosted Bitwarden"
  homepage "https://github.com/b0x42/prizm"

  depends_on macos: ">= :tahoe"

  app "Prizm.app"
end
