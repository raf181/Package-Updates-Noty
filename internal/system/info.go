package system

import (
	"bufio"
	"net"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

type Info struct {
	Hostname string
	IP       string
	OS       string
	Uptime   string
	Time     string
}

func GetInfo() Info {
	host, _ := os.Hostname()
	ip := detectOutboundIP()
	osInfo := runtime.GOOS + " " + kernelRelease()
	uptime := readUptime()
	return Info{
		Hostname: host,
		IP:       ip,
		OS:       osInfo,
		Uptime:   uptime,
		Time:     time.Now().Format("2006-01-02 15:04:05"),
	}
}

func detectOutboundIP() string {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return "Unknown"
	}
	defer conn.Close()
	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String()
}

func kernelRelease() string {
	out, err := exec.Command("uname", "-r").Output()
	if err != nil {
		return runtime.GOARCH
	}
	return strings.TrimSpace(string(out))
}

func readUptime() string {
	f, err := os.Open("/proc/uptime")
	if err != nil {
		return "Unknown"
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	if s.Scan() {
		parts := strings.Split(s.Text(), " ")
		if len(parts) > 0 {
			// seconds to hours
			secStr := parts[0]
			var secs float64
			for _, c := range secStr {
				if c == '.' {
					break
				}
				secs = secs*10 + float64(c-'0')
			}
			h := int(secs) / 3600
			return strconvItoa(h) + "h"
		}
	}
	return "Unknown"
}

func strconvItoa(n int) string {
	if n == 0 {
		return "0"
	}
	sign := ""
	if n < 0 {
		sign = "-"
		n = -n
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return sign + string(b[i:])
}
