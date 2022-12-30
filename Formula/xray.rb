class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  url "https://github.com/XTLS/Xray-core/archive/refs/tags/v1.7.0.tar.gz"
  sha256 "6dbf3d9103e62f9e72b7ac231e1d5a65e2a5c40810500a7e757a4ef71dcc32fd"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]
  head "https://github.com/XTLS/Xray-core.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "5021cb6d809d28702223cd2bc5acbb5acf6e4c1784138547cac1c4b954a53b58"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "0b4b6b1ac74a45e9fe722735e989a3020cdc95f64ea9d157dc5f9789508f332a"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "bab8777737454987c71ace9510f0da4855c360aec620516196354c46444ce830"
    sha256 cellar: :any_skip_relocation, ventura:        "5249e5f1f7f1cffa7c310cac7bccda5fa9237b771bdfc580e0df1d27401ecfda"
    sha256 cellar: :any_skip_relocation, monterey:       "4eba3848ea90a9e4c7535533ebfc5a4969f6f5f4e0a8c72c72999f33cbf1a3ac"
    sha256 cellar: :any_skip_relocation, big_sur:        "e72067c1689786e1fc4d9c5758e1ca783e21cbcf4d2efe86156d89caecdcf781"
    sha256 cellar: :any_skip_relocation, catalina:       "fbe7bda7e6ef94bc3b3b7d706dbfce376e4842efc008eebc3124808e58ff4d3b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "1b03dad5bd6261df69a01aa54cb71ddfce69d6a84b88c34c94d835fcc47988be"
  end

  depends_on "go" => :build

  resource "geoip" do
    url "https://github.com/v2fly/geoip/releases/download/202212290044/geoip.dat"
    sha256 "da84c95fcc09bdb60334cf4ff0d26e6ff1c3d7906a9c5c91d69556a425558677"
  end

  resource "geosite" do
    url "https://github.com/v2fly/domain-list-community/releases/download/20221230094252/dlc.dat"
    sha256 "ed244308475f880a06a02ebd7872790bb32704ca3bdc7c79070aa35f496080e0"
  end

  resource "example_config" do
    # borrow v2ray example config
    url "https://raw.githubusercontent.com/v2fly/v2ray-core/v4.44.0/release/config/config.json"
    sha256 "1bbadc5e1dfaa49935005e8b478b3ca49c519b66d3a3aee0b099730d05589978"
  end

  def install
    ldflags = "-s -w -buildid="
    execpath = libexec/name
    system "go", "build", *std_go_args(output: execpath, ldflags: ldflags), "./main"
    (bin/"xray").write_env_script execpath,
      XRAY_LOCATION_ASSET: "${XRAY_LOCATION_ASSET:-#{pkgshare}}"

    pkgshare.install resource("geoip")
    resource("geosite").stage do
      pkgshare.install "dlc.dat" => "geosite.dat"
    end
    pkgetc.install resource("example_config")
  end

  def caveats
    <<~EOS
      An example config is installed to #{etc}/xray/config.json
    EOS
  end

  service do
    run [opt_bin/"xray", "run", "--config", "#{etc}/xray/config.json"]
    run_type :immediate
    keep_alive true
  end

  test do
    (testpath/"config.json").write <<~EOS
      {
        "log": {
          "access": "#{testpath}/log"
        },
        "outbounds": [
          {
            "protocol": "freedom",
            "tag": "direct"
          }
        ],
        "routing": {
          "rules": [
            {
              "ip": [
                "geoip:private"
              ],
              "outboundTag": "direct",
              "type": "field"
            },
            {
              "domains": [
                "geosite:private"
              ],
              "outboundTag": "direct",
              "type": "field"
            }
          ]
        }
      }
    EOS
    output = shell_output "#{bin}/xray -c #{testpath}/config.json -test"

    assert_match "Configuration OK", output
    assert_predicate testpath/"log", :exist?
  end
end
