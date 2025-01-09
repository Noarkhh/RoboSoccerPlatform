defmodule RoboSoccerPlatform.ConfigUtilsTest do
  use RoboSoccerPlatformWeb.ConnCase

  alias RoboSoccerPlatform.ConfigUtils

  test "parse_ip_address/1 parse correct IP address" do
    assert {192,168,1,1} == ConfigUtils.parse_ip_address!("192.168.1.1")
  end

  test "parse_ip_address/1 raises runtime error for incorrect IP address" do
    assert_raise(
      RuntimeError,
      fn -> ConfigUtils.parse_ip_address!("wrong_ip") end
    )
  end
end
