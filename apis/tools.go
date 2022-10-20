//go:build tools

// Place any runtime dependencies as imports in this file.
// Go modules will be forced to download and install them.
package apis

import (
	_ "sigs.k8s.io/controller-tools/cmd/controller-gen"
)
