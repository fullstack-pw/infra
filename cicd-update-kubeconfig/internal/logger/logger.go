package logger

import (
	"log"
	"os"
)

// Logger provides structured logging for the application
type Logger struct {
	debug bool
}

// New creates a new logger instance
func New(debug bool) *Logger {
	return &Logger{debug: debug}
}

// Info logs an informational message
func (l *Logger) Info(format string, v ...interface{}) {
	log.Printf("INFO: "+format, v...)
}

// Warn logs a warning message
func (l *Logger) Warn(format string, v ...interface{}) {
	log.Printf("WARN: "+format, v...)
}

// Error logs an error message
func (l *Logger) Error(format string, v ...interface{}) {
	log.Printf("ERROR: "+format, v...)
}

// Debug logs a debug message if debug mode is enabled
func (l *Logger) Debug(format string, v ...interface{}) {
	if l.debug {
		log.Printf("DEBUG: "+format, v...)
	}
}

// Fatal logs a fatal error and exits
func (l *Logger) Fatal(format string, v ...interface{}) {
	log.Printf("FATAL: "+format, v...)
	os.Exit(1)
}
