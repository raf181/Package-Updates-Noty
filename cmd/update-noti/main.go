package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/raf181/Package-Updates-Noty/internal/config"
	"github.com/raf181/Package-Updates-Noty/internal/logging"
	"github.com/raf181/Package-Updates-Noty/internal/notify"
	"github.com/raf181/Package-Updates-Noty/internal/pm"
	"github.com/raf181/Package-Updates-Noty/internal/system"
)

var (
	flagConfig         = flag.String("config", "/opt/update-noti/config.json", "Path to config.json")
	flagInstallComplete = flag.Bool("install-complete", false, "Send installation completion notification and exit")
	flagVersion        = flag.Bool("version", false, "Print version and exit")
)

func main() {
	flag.Parse()

	if *flagVersion {
		fmt.Println(versionString())
		return
	}

	cfg, err := config.Load(*flagConfig)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
		os.Exit(1)
	}

	logging.Setup(cfg.Telemetry.LogLevel, cfg.Telemetry.LogFile)
	log := logging.L()

	if *flagInstallComplete {
		doInstallComplete(cfg)
		return
	}

	mgr := pm.Detect()
	if mgr == "" {
		fmt.Fprintln(os.Stderr, "No supported package manager found.")
		os.Exit(1)
	}

	sys := system.GetInfo()
	upgradable, _ := pm.Upgradable(mgr)

	slack := notify.NewSlack(cfg)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if len(upgradable) == 0 {
		msg := header("SYSTEM UPDATE CHECK") + fields(sys, string(mgr)) + sep() + "✅ STATUS: All packages are up to date! 🎉" + footer()
		_ = slack.Send(ctx, notify.SimpleText(msg))
		return
	}

	// Decide auto-update subset
	autoSet := map[string]struct{}{}
	for _, p := range cfg.AutoUpdate { autoSet[p] = struct{}{} }
	var toUpdate []string
	for _, p := range upgradable { if _, ok := autoSet[p]; ok { toUpdate = append(toUpdate, p) } }
	updated := pm.AutoUpdate(mgr, toUpdate)

	msg := header("SYSTEM UPDATE CHECK") + fields(sys, string(mgr)) + sep()
	if len(upgradable) <= 10 {
		msg += fmt.Sprintf("🔄 AVAILABLE UPDATES (%d):\n%s\n", len(upgradable), bulletList(upgradable, "• "))
	} else {
		msg += fmt.Sprintf("🔄 AVAILABLE UPDATES (%d):\n`%s`\n", len(upgradable), strings.Join(upgradable, ", "))
	}
	msg += sep()
	if len(updated) > 0 {
		if len(updated) <= 5 {
			msg += fmt.Sprintf("🛠️ AUTO-UPDATED (%d):\n%s\n", len(updated), bulletList(updated, "✅ "))
		} else {
			msg += fmt.Sprintf("🛠️ AUTO-UPDATED (%d):\n`%s`\n", len(updated), strings.Join(updated, ", "))
		}
		msg += sep() + "✅ STATUS: Updates completed successfully! 🚀"
	} else {
		msg += "⚠️ STATUS: Updates available but none auto-updated"
	}
	msg += footer()

	if err := slack.Send(ctx, notify.SimpleText(msg)); err != nil {
		log.Warn("failed to send slack message", "error", err)
	}
}

func doInstallComplete(cfg *config.Config) {
	sys := system.GetInfo()
	msg := header("UPDATE-NOTI INSTALLED!") +
		fmt.Sprintf("📅 Time: `%s`\n", sys.Time) +
		fmt.Sprintf("🖥️ Host: `%s` (`%s`)\n", sys.Hostname, sys.IP) +
		fmt.Sprintf("💻 OS: `%s`\n", sys.OS) +
		fmt.Sprintf("⏰ Uptime: `%s`\n", sys.Uptime) +
		"📍 Location: `/opt/update-noti`\n" +
		"📦 Method: Binary from GitHub releases\n" +
		"✅ Status: Installation completed successfully! 🚀" +
		sep() + "⏰ Schedule: Daily at 01:00 + boot backup\n" +
		"🔄 Auto-update: Enabled\n" +
		"📝 Config: `/opt/update-noti/config.json`" + footer()

	slack := notify.NewSlack(cfg)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = slack.Send(ctx, notify.SimpleText(msg))
}

func header(title string) string {
	line := strings.Repeat("━", 40)
	return line + "\n" + "🔍 *" + title + "* 🔍\n" + line + "\n"
}

func sep() string { return strings.Repeat("━", 40) + "\n" }

func footer() string { return "\n" + strings.Repeat("━", 40) }

func bulletList(items []string, prefix string) string {
	var b strings.Builder
	for _, s := range items {
		b.WriteString("  ")
		b.WriteString(prefix)
		b.WriteString("`")
		b.WriteString(s)
		b.WriteString("`\n")
	}
	return b.String()
}

func fields(sys system.Info, mgr string) string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf("📅 Time: `%s`\n", sys.Time))
	b.WriteString(fmt.Sprintf("🖥️ Host: `%s` (`%s`)\n", sys.Hostname, sys.IP))
	b.WriteString(fmt.Sprintf("💻 OS: `%s`\n", sys.OS))
	b.WriteString(fmt.Sprintf("⏰ Uptime: `%s`\n", sys.Uptime))
	b.WriteString(fmt.Sprintf("📦 Package Manager: `%s`\n", mgr))
	return b.String()
}

func versionString() string { return fmt.Sprintf("update-noti %s", Version) }

var Version = "dev"
