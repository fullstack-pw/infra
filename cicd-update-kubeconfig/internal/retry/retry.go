package retry

import (
	"time"

	retrygo "github.com/avast/retry-go/v4"
)

// Config defines retry behavior
type Config struct {
	Attempts uint
	Delay    time.Duration
}

// DefaultConfig returns default retry configuration
func DefaultConfig() Config {
	return Config{
		Attempts: 3,
		Delay:    30 * time.Second,
	}
}

// Do executes a function with retry logic
func Do(fn func() error, cfg Config, onRetry func(n uint, err error)) error {
	opts := []retrygo.Option{
		retrygo.Attempts(cfg.Attempts),
		retrygo.Delay(cfg.Delay),
		retrygo.DelayType(retrygo.FixedDelay),
	}

	if onRetry != nil {
		opts = append(opts, retrygo.OnRetry(onRetry))
	}

	return retrygo.Do(fn, opts...)
}
