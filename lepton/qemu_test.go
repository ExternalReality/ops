package lepton

import (
	"strings"
	"testing"
)

func TestRenderDriveWithIndex(t *testing.T) {
	testDrive := &drive{path: "image", format: "raw", index: "0"}
	expected := "-drive file=image,format=raw,index=0"
	checkQemuRender(testDrive, expected, t)
}

func TestRenderDriveWithIfType(t *testing.T) {
	testDrive := &drive{path: "image", format: "raw", iftype: "virtio"}
	expected := "-drive file=image,format=raw,if=virtio"
	checkQemuRender(testDrive, expected, t)
}

func TestRenderDevice(t *testing.T) {
	testDevice := &device{driver: "virtio-net", mac: "7e:b8:7e:87:4a:ea", netdevid: "n0"}
	expected := "-device virtio-net,netdev=n0,mac=7e:b8:7e:87:4a:ea"
	checkQemuRender(testDevice, expected, t)
}

func TestRenderNetDev(t *testing.T) {
	testNetDev := &netdev{
		nettype:    "tap",
		id:         "n0",
		ifname:     "tap0",
		script:     "no",
		downscript: "no",
	}
	expected := "-netdev tap,id=n0,ifname=tap0,script=no,downscript=no"
	checkQemuRender(testNetDev, expected, t)
}

func TestRenderNetDevWithHostPortForwarding(t *testing.T) {
	testHostPorts := []portfwd{{proto: "tcp", port: 80}, {proto: "tcp", port: 443}}
	testNetDev := &netdev{nettype: "user", id: "n0", hports: testHostPorts}
	expected := "-netdev user,id=n0,hostfwd=tcp::80-:80,hostfwd=tcp::443-:443"
	checkQemuRender(testNetDev, expected, t)
}

func TestRenderDisplay(t *testing.T) {
	testDisplay := &display{disptype: "none"}
	expected := "-display none"
	checkQemuRender(testDisplay, expected, t)
}

func TestRenderSerial(t *testing.T) {
	testSerial := &serial{serialtype: "stdio"}
	expected := "-serial stdio"
	checkQemuRender(testSerial, expected, t)
}

func checkQemuRender(qr QemuRender, expected string, t *testing.T) {
	actual := strings.Join(qr.render(), " ")
	if expected != actual {
		t.Errorf("rendered %q not %q", actual, expected)
	}
}
