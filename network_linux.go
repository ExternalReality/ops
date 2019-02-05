package main

import (
	"context"

	"github.com/google/netstack/dhcp"
	"github.com/google/netstack/tcpip"
	"github.com/google/netstack/tcpip/network/ipv4"
	"github.com/google/netstack/tcpip/stack"
	"github.com/google/netstack/tcpip/transport/udp"
	"github.com/vishvananda/netlink"
)

func addTapDevice(name string, bridge *netlink.Bridge) error {
	tap0 := &netlink.Tuntap{
		LinkAttrs: netlink.LinkAttrs{Name: name},
		Mode:      netlink.TUNTAP_MODE_TAP,
	}
	if err := netlink.LinkAdd(tap0); err != nil {
		return err
	}
	// bring up tap0
	if err := netlink.LinkSetUp(tap0); err != nil {
		return err
	}
	if err := netlink.LinkSetMaster(tap0, bridge); err != nil {
		return err
	}
	return nil
}

func setupBridgeNetwork() error {
	var err error
	eth0, err := findFirstActiveAdapter()
	if err != nil {
		return err
	}
	bridge, err := createBridgeNetwork(eth0.Name)
	if err != nil {
		return err
	}
	err = assignIP(bridge)
	if err != nil {
		return err
	}
	return nil
}

func dhcpAcquireIPAddress(mac string) (string, error) {
	s := stack.New([]string{ipv4.ProtocolName}, []string{udp.ProtocolName}, stack.Options{})

	// we might need to cache mac before we can
	// use random mac.
	//m :=  randomMacAddress()
	m, _ := tcpip.ParseMACAddress(mac)
	c := dhcp.NewClient(s, tcpip.NICID(1), m, nil)
	_, err := c.Request(context.Background(), "")
	if err != nil {
		return "", err
	}

	return c.Address().String(), nil
}
