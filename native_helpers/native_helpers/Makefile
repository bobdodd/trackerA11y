# Makefile for building the native macOS event capture helper

# Compiler and flags
CC = clang
FRAMEWORKS = -framework ApplicationServices -framework Foundation -framework Carbon
CFLAGS = -Wall -Wextra -O2
TARGET = mouse_capture
SOURCE = mouse_capture.m

# Default target
all: $(TARGET)

# Build the native helper
$(TARGET): $(SOURCE)
	@echo "Building native macOS event capture helper..."
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(SOURCE) -o $(TARGET)
	@echo "✅ Built $(TARGET) successfully"
	@echo ""
	@echo "To test the native helper:"
	@echo "  ./$(TARGET)"
	@echo ""
	@echo "To use with Node.js:"
	@echo "  node ../examples/native-recorder-demo.js"
	@echo ""

# Test the helper (runs for 5 seconds then stops)
test: $(TARGET)
	@echo "🧪 Testing native event capture (will run for 5 seconds)..."
	@echo "Try clicking or pressing keys..."
	@timeout 5 ./$(TARGET) || echo "Test completed"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(TARGET)
	@echo "✅ Clean complete"

# Install to system path (optional)
install: $(TARGET)
	@echo "Installing to /usr/local/bin..."
	sudo cp $(TARGET) /usr/local/bin/
	@echo "✅ Installed $(TARGET) to /usr/local/bin"

# Show build info
info:
	@echo "Native macOS Event Capture Helper"
	@echo "================================="
	@echo "Source: $(SOURCE)"
	@echo "Target: $(TARGET)"
	@echo "Frameworks: $(FRAMEWORKS)"
	@echo "Compiler: $(CC)"
	@echo ""
	@echo "Usage:"
	@echo "  make          - Build the helper"
	@echo "  make test     - Build and test for 5 seconds"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make install  - Install to system PATH"

.PHONY: all test clean install info