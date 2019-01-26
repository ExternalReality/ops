package lepton

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const qemuBaseCommand = "qemu-system-x86_64"

type QemuRender interface {
	render() []string
}

type drive struct {
	path   string
	format string
	iftype string
	index  string
}

type device struct {
	driver   string
	mac      string
	netdevid string
}

type netdev struct {
	nettype    string
	id         string
	ifname     string
	script     string
	downscript string
	hports     []portfwd
}

type portfwd struct {
	port  int
	proto string
}

type display struct {
	disptype string
}

type serial struct {
	serialtype string
}

type qemu struct {
	cmd     *exec.Cmd
	drives  []drive
	devices []device
	ifaces  []netdev
	display display
	serial  serial
}

func (d *display) render() []string {
	return []string{"-display", fmt.Sprintf("%s", d.disptype)}
}

func (s *serial) render() []string {
	return []string{"-serial", fmt.Sprintf("%s", s.serialtype)}
}

func (d *drive) render() []string {
	str := fmt.Sprintf("file=%s,format=%s", d.path, d.format)
	if len(d.index) > 0 {
		str = str + "," + fmt.Sprintf("index=%s", d.index)
	}
	if len(d.iftype) > 0 {
		str = str + "," + fmt.Sprintf("if=%s", d.iftype)
	}
	return []string{"-drive", str}
}

func (dv *device) render() []string {
	str := fmt.Sprintf("%s,netdev=%s", dv.driver, dv.netdevid)
	if len(dv.mac) > 0 {
		str = str + "," + fmt.Sprintf("mac=%s", dv.mac)
	}
	return []string{"-device", str}
}

func (nd *netdev) render() []string {
	var str string
	str = fmt.Sprintf("%s,id=%s", nd.nettype, nd.id)
	if len(nd.ifname) > 0 {
		str += "," + fmt.Sprintf("ifname=%s", nd.ifname)
	}
	if len(nd.script) > 0 {
		str += "," + fmt.Sprintf("script=%s", nd.script)
	}
	if len(nd.downscript) > 0 {
		str += "," + fmt.Sprintf("downscript=%s", nd.downscript)
	}
	for _, hport := range nd.hports {
		str += "," + hport.render()[0]
	}
	return []string{"-netdev", str}
}

func (pf *portfwd) render() []string {
	str := fmt.Sprintf("hostfwd=%s::%v-:%v", pf.proto, pf.port, pf.port)
	return []string{str}
}

func (q *qemu) Stop() {
	if q.cmd != nil {
		q.cmd.Process.Kill()
	}
}

func logv(rconfig *RunConfig, msg string) {
	if rconfig.Verbose {
		fmt.Println(msg)
	}
}

func (q *qemu) Command(rconfig *RunConfig) *exec.Cmd {
	args := q.Args(rconfig)
	q.cmd = exec.Command(qemuBaseCommand, args...)
	return q.cmd
}

func (q *qemu) Start(rconfig *RunConfig) error {
	args := q.Args(rconfig)
	logv(rconfig, qemuBaseCommand+" "+strings.Join(args, " "))
	q.cmd = exec.Command(qemuBaseCommand, args...)
	q.cmd.Stdout = os.Stdout
	q.cmd.Stdin = os.Stdin
	q.cmd.Stderr = os.Stderr

	if err := q.cmd.Run(); err != nil {
		fmt.Println(err)
		return err
	}
	return nil
}

func (q *qemu) Args(rconfig *RunConfig) []string {
	// todo create a qemu from serial
	args := []string{}
	boot := drive{path: "image", format: "raw", index: "0"}
	storage := drive{path: "image", format: "raw", iftype: "virtio"}
	dev := device{driver: "virtio-net", mac: "7e:b8:7e:87:4a:ea", netdevid: "n0"}
	ndev := netdev{nettype: "tap", id: "n0", ifname: "tap0"}
	display := display{disptype: "none"}
	serial := serial{serialtype: "stdio"}
	if !rconfig.Bridged {
		hps := []portfwd{}
		for _, p := range rconfig.Ports {
			hps = append(hps, portfwd{port: p, proto: "tcp"})
		}
		dev = device{driver: "virtio-net", netdevid: "n0"}
		ndev = netdev{nettype: "user", id: "n0", hports: hps}
	}
	args = append(args, display.render()...)
	args = append(args, serial.render()...)
	args = append(args, boot.render()...)
	args = append(args, display.render()...)
	args = append(args, []string{"-nodefaults", "-no-reboot", "-m", rconfig.Memory, "-device", "isa-debug-exit"}...)
	args = append(args, storage.render()...)
	args = append(args, dev.render()...)
	args = append(args, ndev.render()...)
	if rconfig.Bridged {
		args = append(args, "-enable-kvm")
	}
	return args
}

func newQemu() Hypervisor {
	return &qemu{}
}
