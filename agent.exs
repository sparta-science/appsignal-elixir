defmodule Appsignal.Agent do
  def version, do: "76c2b99"

  def triples do
    %{
      "x86_64-darwin" => %{
        checksum: "a41bf7bb2f3cb3087d3442b0c010d662dc1d4cbf81c64a9fbcf37067297c3226",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "universal-darwin" => %{
        checksum: "a41bf7bb2f3cb3087d3442b0c010d662dc1d4cbf81c64a9fbcf37067297c3226",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-x86_64-darwin-all-static.tar.gz"
      },
      "i686-linux" => %{
        checksum: "16b4d679e0dce9a38d760cd39db32d352fb757d949c102fe6863e04914c0b97d",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-i686-linux-all-static.tar.gz"
      },
      "x86-linux" => %{
        checksum: "16b4d679e0dce9a38d760cd39db32d352fb757d949c102fe6863e04914c0b97d",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-i686-linux-all-static.tar.gz"
      },
      "i686-linux-musl" => %{
        checksum: "77a89432610b6d996cac533b8ec5ef58cae6174b6d86e0dd2708a9dfddbf57e7",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-i686-linux-musl-all-static.tar.gz"
      },
      "x86-linux-musl" => %{
        checksum: "77a89432610b6d996cac533b8ec5ef58cae6174b6d86e0dd2708a9dfddbf57e7",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-i686-linux-musl-all-static.tar.gz"
      },
      "x86_64-linux" => %{
        checksum: "9eb71bd699f70538ff9b665a0ac73f00e130959d44e31d4cba178e9071686db6",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-x86_64-linux-all-static.tar.gz"
      },
      "x86_64-linux-musl" => %{
        checksum: "bb553a1a63153724251b391db4d5408ac8508ba62bd137bf79784120cab2a4c4",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-x86_64-linux-musl-all-static.tar.gz"
      },
      "x86_64-freebsd" => %{
        checksum: "c53f5ac1d55187e9c3e6df1830424154f8d347f7b6ca8a5befcd6d7f8e1baca2",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-x86_64-freebsd-all-static.tar.gz"
      },
      "amd64-freebsd" => %{
        checksum: "c53f5ac1d55187e9c3e6df1830424154f8d347f7b6ca8a5befcd6d7f8e1baca2",
        download_url: "https://appsignal-agent-releases.global.ssl.fastly.net/76c2b99/appsignal-x86_64-freebsd-all-static.tar.gz"
      },
    }
  end
end
