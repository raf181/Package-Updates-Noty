package config

import (
	"encoding/json"
	"os"
)

type Config struct {
	SlackWebhook string   `json:"slack_webhook"`
	AutoUpdate   []string `json:"auto_update"`
	Telemetry    Tele     `json:"telemetry"`
	Global       *Global  `json:"global,omitempty"`
}

type Tele struct {
	LogLevel string `json:"log_level"`
	LogFile  string `json:"log_file"`
}

func Load(path string) (*Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var c Config
	if err := json.Unmarshal(b, &c); err != nil {
		return nil, err
	}
	c.setDefaults()
	if err := c.validate(); err != nil {
		return nil, err
	}
	return &c, nil
}

func (c *Config) setDefaults() {
	if c.Telemetry.LogLevel == "" {
		c.Telemetry.LogLevel = "INFO"
	}
	// Init default global slack container if missing
	if c.Global == nil {
		c.Global = &Global{}
	}
}

func (c *Config) validate() error {
	if c.SlackWebhook == "" {
		// allow empty, the app will print to stdout instead of sending
	}
	return nil
}

// Global holds shared settings that can be used across agents
type Global struct {
	Slack Slack `json:"slack"`
}

type Slack struct {
	DefaultWebhook string            `json:"default_webhook"`
	Routes         map[string]string `json:"routes"`
}
