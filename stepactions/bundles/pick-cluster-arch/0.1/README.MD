# pick-cluster-arch stepaction

This StepAction retrieves the supported architectures for a bundle by checking the "operatorframework.io/arch" labels on the bundle CSV.
If arm64 is supported, the StepAction returns it; otherwise, it returns amd64.
If neither arm64 nor amd64 are supported, the step exits with an error.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|bundleImage|A bundle image.||true|

## Results
|name|description|
|---|---|
|bundleArch|A bundle-supported architecture, arm64 or amd64.|