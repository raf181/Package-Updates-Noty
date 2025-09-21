package pm

import (
	"bufio"
	"bytes"
	"os/exec"
	"regexp"
	"sort"
	"strings"
)

type Manager string

const (
	APT    Manager = "apt"
	DNF    Manager = "dnf"
	YUM    Manager = "yum"
	PACMAN Manager = "pacman"
	ZYPER  Manager = "zypper"
)

func Detect() Manager {
	if has("apt") {
		return APT
	}
	if has("dnf") {
		return DNF
	}
	if has("yum") {
		return YUM
	}
	if has("pacman") {
		return PACMAN
	}
	if has("zypper") {
		return ZYPER
	}
	return ""
}

func has(bin string) bool { return which(bin) }

func which(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// Upgradable returns a sorted list of packages with available updates.
func Upgradable(m Manager) ([]string, error) {
	switch m {
	case APT:
		out, _ := exec.Command("apt", "list", "--upgradable").Output()
		lines := bytes.Split(out, []byte("\n"))
		var pkgs []string
		for i, line := range lines {
			if i == 0 || len(line) == 0 { // skip header
				continue
			}
			pkg := strings.SplitN(string(line), "/", 2)[0]
			if pkg != "" {
				pkgs = append(pkgs, pkg)
			}
		}
		return uniqueSorted(pkgs), nil
	case DNF, YUM:
		cmd := "dnf"
		if m == YUM { cmd = "yum" }
		out, _ := exec.Command(cmd, "check-update").Output()
		scanner := bufio.NewScanner(bytes.NewReader(out))
		var pkgs []string
		reHeader := regexp.MustCompile(`^(Last metadata expiration|Obsoleting Packages|Loaded plugins)`) 
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || reHeader.MatchString(line) { continue }
			parts := strings.Fields(line)
			if len(parts) > 0 && !strings.HasPrefix(parts[0], "=") {
				pkgs = append(pkgs, parts[0])
			}
		}
		return uniqueSorted(pkgs), nil
	case PACMAN:
		out, _ := exec.Command("pacman", "-Qu").Output()
		scanner := bufio.NewScanner(bytes.NewReader(out))
		var pkgs []string
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" { continue }
			parts := strings.Fields(line)
			if len(parts) > 0 {
				pkgs = append(pkgs, parts[0])
			}
		}
		return uniqueSorted(pkgs), nil
	case ZYPER:
		out, _ := exec.Command("zypper", "list-updates").Output()
		scanner := bufio.NewScanner(bytes.NewReader(out))
		var pkgs []string
		for scanner.Scan() {
			line := scanner.Text()
			if strings.Contains(line, "|") && !strings.Contains(line, "Package") {
				parts := strings.Split(line, "|")
				if len(parts) >= 3 {
					pkgs = append(pkgs, strings.TrimSpace(parts[2]))
				}
			}
		}
		return uniqueSorted(pkgs), nil
	}
	return nil, nil
}

// AutoUpdate installs the given packages using the detected manager; returns successfully updated.
func AutoUpdate(m Manager, pkgs []string) []string {
	if len(pkgs) == 0 { return nil }
	var updated []string
	for _, p := range pkgs {
		var cmd *exec.Cmd
		switch m {
		case APT:
			cmd = exec.Command("apt-get", "install", "-y", p)
		case DNF:
			cmd = exec.Command("dnf", "upgrade", "-y", p)
		case YUM:
			cmd = exec.Command("yum", "update", "-y", p)
		case PACMAN:
			cmd = exec.Command("pacman", "-S", "--noconfirm", p)
		case ZYPER:
			cmd = exec.Command("zypper", "--non-interactive", "update", p)
		default:
			continue
		}
		if err := cmd.Run(); err == nil {
			updated = append(updated, p)
		}
	}
	return updated
}

func uniqueSorted(in []string) []string {
	m := map[string]struct{}{}
	for _, s := range in { m[s] = struct{}{} }
	out := make([]string, 0, len(m))
	for s := range m { out = append(out, s) }
	sort.Strings(out)
	return out
}
